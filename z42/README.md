# z42 实现

同一套确定性战斗核，用 [z42](https://github.com/z42-lang/z42) 重写一份。规则和 [`../go/sim.go`](../go/sim.go) 顶部完全同构，`world_hash` / `damage_total` / `alive_players` 必须逐字节对齐。

**这个目录是独立的一份，不接入 `../scripts/compare.sh` / `run_matrix.sh` / `run_long.sh`**：z42 目前是 0.7.0（开发中的 nightly 级语言），工具链和安装方式都独立，不适合挂进五方对拍脚本。跑法全部在本目录内闭环。

## 1. 装 z42

```bash
curl -fsSL https://z42-lang.github.io/z42/install-z42.sh | sh
export PATH="$HOME/.z42:$HOME/.z42/bin:$PATH"   # 装到 ~/.z42
z42 --version                                    # z42 0.7.0 (linux-x64, ...)
```

官方 SDK 的二进制要求 **GLIBC 2.39**。Ubuntu 24.04+ 直接能跑；Ubuntu 22.04（glibc 2.35）需要自己补一个 2.39 的 loader，做法见 [`NOTES.md`](NOTES.md)。

## 2. 构建与运行

```bash
./run.sh --rooms 1 --players 40 --ticks 200 --seed 1234 --workload medium --alloc arena
```

`run.sh` 会先 `z42c build --release --opt all`，再 `z42 dist/z42-battle.zpkg -- <参数>`。参数和 Go 版一致：

```
--rooms N --players N --ticks N --seed N
--workload low|medium|high|insane
--alloc naive|arena
--spin-us N      # 到点前最后 N 微秒忙等，默认 1000
--workers N      # 默认 -1=min(CPU 数, 房间数)；0=一房一线程；N=固定 worker 池
```

`z42 run` 只会出 debug 产物且每次重编；压测请走 `run.sh`。

## 3. 怎么实现的

- 语言侧没有 `ulong` 位运算（0.7.0 里 `ulong` 的 `^` / `>>` 不可用），64 位哈希用 `long` 承载，右移用 `LShr(x,n) = (x >> n) & ((1L << (64-n)) - 1)` 模拟逻辑右移。`long` 乘法按 2^64 自然回绕，和 Go 的 `uint64` 一致。
- 无符号取模：z42 的 `%` 余数跟被除数走（`-5 % 7 == -5`），而 Go 的 `uint64 % d` 是无符号。`UMod()` 先把负数折到 `[0,d)`，`2^64 mod d` 由 64 次倍增算出。注意判据必须是 `x >= 0` 而不是 `r >= 0`，否则 `x` 为负且整余时会漏折（`0x...f6 % 10` 这种）。
- 调度默认是**固定 worker 池**：`min(CPU 数, 房间数)` 个 `Thread`，房间按下标 round-robin 分给 worker；每个 worker 在每个 50ms 到期点醒来，依次 tick 自己名下的房间。`--workers 0` 回到「一房一线程」，用于对照。z42 0.7.0 没有 async/`spawn`/绿色线程（只有 `Thread` / `Mutex` / `Channel`），所以线程数就是 OS 线程数，必须自己控。
- `arena` 用 **free-list** 复用弹道 / buff 对象：压缩时把死对象推进 `ProjFree` / `BuffFree`，spawn 时弹出，压缩后把尾部槽位置 `null`。不能按「槽位下标复用」——压缩后同一活对象可能被两个槽引用，复用会覆盖活对象，hash 立刻跑偏。
- `naive` 每 tick 新建 snapshot、弹道、buff、事件；`arena` 只复用短命对象，玩家和 snapshot 数组仍然常驻。
- `alloc_bytes` 固定 0：z42 0.7.0 不暴露分配字节数。`alloc_objects` 用 `RuntimeStats.Counters().Allocations` 差值；RSS 读 `/proc/self/status` 的 `VmHWM`，CPU 读 `/proc/self/stat` 的 utime+stime（USER_HZ=100）。

## 4. 正确性（seed 1234）

z42 与 Go 参考实现逐字段对比，`world_hash` / `damage_total` / `alive_players` 全部一致：

| rooms | players | ticks | workload | alloc | world_hash | damage | alive |
|---|---|---|---|---|---|---|---|
| 1 | 40 | 200 | medium | arena | `ad2d471bee2634ea` | 6778 | 40 |
| 1 | 40 | 200 | medium | naive | `ad2d471bee2634ea` | 6778 | 40 |
| 3 | 40 | 200 | high | arena | `ba4a9e097e079029` | 33762 | 120 |
| 5 | 40 | 400 | medium | arena | `d13ef926b723e826` | 72640 | 200 |
| 2 | 12 | 300 | low | naive | `0f5779d90da61806` | 2224 | 24 |
| 1 | 40 | 1000 | insane | arena | `0114bd6be92d4baf` | 39004 | 6 |
| 1 | 40 | 400 | medium | arena | `ff640dfc221dfc4e` | 13998 | 40 |
| 100 | 40 | 600 | high | arena | `b7dbfaafa4c6ae81` | 3334850 | 4000 |

对拍命令：

```bash
cd .. && go build -o /tmp/battle_go . && cd z42
./run.sh --rooms 1 --players 40 --ticks 200 --seed 1234 --workload medium --alloc arena
/tmp/battle_go --rooms 1 --players 40 --ticks 200 --seed 1234 --workload medium --alloc arena
```

## 5. 本机数据

豆包云主机（Linux x64，4 vCPU，glibc 2.35 + 自带 2.39 loader），seed 1234，600 tick，40 人/房，`--spin-us 1000`，Go 为同机同参数：

| lang | alloc | rooms | workers | lag p50 | lag p99 | lag max | 超 50ms | compute p50 | compute p99 | RSS | CPU |
|---|---|---|---|---|---|---|---|---|---|---|---|
| z42 | arena | 1 | 1 | 0.15ms | 0.22ms | 0.36ms | 0 | 139µs | 200µs | 25MB | 1.2s |
| z42 | arena | 10 | 4 | 0.23ms | 0.48ms | 1.30ms | 0 | 101µs | 189µs | 29MB | 4.7s |
| z42 | arena | 50 | 4 | 0.70ms | 1.66ms | 19.0ms | 0 | 95µs | 173µs | 30MB | 7.1s |
| z42 | arena | 100 | 4 | 1.33ms | 3.06ms | 4.64ms | 0 | 94µs | 161µs | 32MB | 9.5s |
| z42 | naive | 100 | 4 | 1.51ms | 4.17ms | 14.8ms | 0 | 107µs | 182µs | 47MB | 9.8s |
| Go | arena | 1 | - | 0.57ms | 1.07ms | 1.11ms | 0 | 8µs | 18µs | 2MB | 0.05s |
| Go | arena | 10 | - | 0.61ms | 1.19ms | 7.8ms | 0 | 6µs | 25µs | 2MB | 0.14s |
| Go | arena | 50 | - | 0.65ms | 1.19ms | 1.53ms | 0 | 5µs | 12µs | 4MB | 0.29s |
| Go | arena | 100 | - | 0.76ms | 1.39ms | 1.85ms | 0 | 5µs | 15µs | 5MB | 0.54s |
| Go | naive | 100 | - | 1.02ms | 2.10ms | 2.96ms | 0 | 9µs | 492µs | 8MB | 0.82s |

读法：

- z42 的 compute 是 Go 的 **12–20 倍**（94–139µs vs 5–9µs），原因在 0.7.0 的 JIT 执行速度（本机 1M 次 mix 约 130ns/次），不是内核语义差异。
- 1 房时 z42 的 lag 反而更低（0.15ms vs 0.57ms），因为它最后 1ms 忙等；Go 版靠 timer 唤醒，在这台云主机上 baseline lag 就是 0.5ms。
- worker 池把 compute p99 也压下来了：100 房 arena 从一房一线程的 1.29ms 降到 161µs，naive 从 2.60ms 降到 182µs——线程数少了，分配/GC 路径上的争用跟着少。
- 50 房 arena 的 max 19ms 是一次系统调度抖动，不是 GC（`runtime.major_collections=0`）；naive 100 房的 max 14.8ms 伴随 9 次 minor collection。
- CPU 包含忙等和 JIT：100 房 600 tick 下 `--spin-us 1000` 是 9.5s，`--spin-us 0` 是 8.5s；纯 compute 约 5.6s（100 房 × 600 tick × ~94µs）。

### 1000 房：线程数与 worker 池

600 tick、medium、arena、seed 1234，同一台 4 vCPU 云主机，只改 `--workers`：

| workers | 线程数 | lag p50 | lag p99 | lag max | 超 50ms | compute p50 | compute p99 | RSS | CPU |
|---|---|---|---|---|---|---|---|---|---|
| 0（一房一线程） | 1000 | 14.3ms | **301.8ms** | **929.6ms** | **16549** | 98µs | 21.0ms | 94MB | 69.3s |
| 8 | 8 | 12.6ms | 26.4ms | 36.4ms | 0 | 95µs | 3.11ms | 72MB | 62.9s |
| 4（默认） | 4 | 12.4ms | **25.2ms** | 38.5ms | 0 | 95µs | **150µs** | 70MB | 62.0s |

同一份 `world_hash=b61def3711760a01`（Go 同参数也是它），只差调度。1000 个 OS 线程挤 4 核、每个线程每 50ms 醒一次再忙等 1ms，会把 p99 推到 300ms、max 推到 930ms；固定 4 个 worker 后 p99 25ms、0 次超预算。8 个 worker 在 4 核上过订阅，compute p99 反而涨到 3.1ms。

注意 worker 池的 lag 下限：4 个 worker 每个背 250 房，每 tick 这批要算 ~25ms，队列中位大约落在一半（12ms），所以 p50 比 100 房时高。这是「房间在 worker 上排队」的成本，不是内核变慢（compute p50 仍是 95µs）。

2 分钟浸泡（100 房，2400 tick，high，arena，默认 4 worker）：

| 语言 | lag p50 | lag p99 | lag p999 | lag max | 超 50ms | 计算 p50 | 计算 p99 | 计算 max | RSS | CPU |
|---|---|---|---|---|---|---|---|---|---|---|
| z42 | 1.26ms | 3.45ms | 11.7ms | 27.8ms | 0 | 88µs | 191µs | 12.2ms | 41MB | 39.9s |
| Go | 0.75ms | 1.32ms | 1.98ms | 4.07ms | 0 | 6µs | 16µs | 0.77ms | 12MB | 2.4s |

`world_hash=b1cb49ea9f80b211`、伤害 3890134、存活 1437，两边一致。z42 没有超 50ms 的帧；max 从一房一线程时的 45.4ms 降到 27.8ms，计算 max 从 25.0ms 降到 12.2ms。

## 6. 复现矩阵

```bash
# 8 格（1/10/50/100 房 × arena/naive）→ results/matrix_z42.jsonl（git 忽略）
ROOMS="1 10 50 100" ALLOCS="arena naive" WORKLOAD=medium TICKS=600 ./bench_matrix.sh

# 指定 worker 数（0 = 一房一线程），默认不传就是 auto
WORKERS=4 ROOMS="1000" ALLOCS="arena" ./bench_matrix.sh
```

`bench_matrix.sh` 只在本目录内跑，不改 `../scripts/`。结果落在 `z42/results/`，和仓库其它语言的 `results/` 一样不入库。

本机这一轮的数据已经归档在 [`archive/2026-11-18-doubao-cloud/`](archive/2026-11-18-doubao-cloud/)（机器、工具链、摘要见该目录 `NOTES.md`）。
