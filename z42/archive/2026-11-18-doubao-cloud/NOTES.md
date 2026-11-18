# 2026-11-18 z42 0.7.0 / 豆包云主机

## 机器与工具链

- 豆包云主机：Linux x64，4 vCPU，内存 8GB，Ubuntu 22.04（glibc 2.35 + 自带 glibc 2.39 loader，见 `../../NOTES.md`）
- `z42 0.7.0 (linux-x64, 2026-11-15)`，`z42c build --release --opt all`
- Go 对照：`go1.23.0`，`GOMAXPROCS=4`，同机同参数
- seed 1234，40 人/房，`--spin-us 1000`
- 默认调度是 worker 池：`--workers -1` → `min(CpuCount, rooms)`；`--workers 0` = 一房一线程

**这台是 4 vCPU 云主机，和 `archive/2026-08-13-*`（Mac Mini M4 10 核 / 12 核本机）不能横比绝对值。**

## 文件

| 文件 | 内容 |
|---|---|
| `matrix_z42.jsonl` | 8 格短矩阵：1/10/50/100 房 × arena/naive，600 tick，medium，默认 worker 池 |
| `long_100_high.json` | 100 房，2400 tick（2 分钟），high，arena，4 worker |
| `rooms_1000_thread_per_room.json` | 1000 房，600 tick，medium，arena，`--workers 0`（1000 OS 线程） |
| `rooms_1000_workers8.json` | 同上，`--workers 8` |
| `rooms_1000_workers4.json` | 同上，`--workers 4`（默认） |

## 摘要

- 8 格 `world_hash` / `damage_total` / `alive_players` 与同机 Go 全部一致（worker 数与 hash 无关）。
- 2 分钟浸泡：100 房 high，`world_hash=b1cb49ea9f80b211`、伤害 3890134、存活 1437；lag p50 1.26ms / p99 3.45ms / p999 11.7ms / max 27.8ms，超 50ms 0 次。
- 1000 房 600 tick：一房一线程（1000 线程）lag p99 302ms、max 930ms、超预算 16549 次；4 worker 时 p99 25.2ms、max 38.5ms、0 次。三种 worker 数的 `world_hash` 都是 `b61def3711760a01`（Go 同参数一致）。
- 计算 p50 88–95µs（Go 6µs）；线程数减少后 compute p99 从 ms 级降到百µs 级（100 房 arena：1.29ms → 161µs）。

## Go 对照（同机，本目录未入库）

| alloc | rooms | ticks | lag p50 | lag p99 | lag max |
|---|---|---|---|---|---|
| arena | 1 | 600 | 0.57ms | 1.07ms | 1.11ms |
| arena | 10 | 600 | 0.61ms | 1.19ms | 7.8ms |
| arena | 50 | 600 | 0.65ms | 1.19ms | 1.53ms |
| arena | 100 | 600 | 0.76ms | 1.39ms | 1.85ms |
| naive | 100 | 600 | 1.02ms | 2.10ms | 2.96ms |
| arena | 100 | 2400 | 0.75ms | 1.32ms | 4.07ms |
| arena | 1000 | 600 | 1.87ms | 3.22ms | 4.22ms |
