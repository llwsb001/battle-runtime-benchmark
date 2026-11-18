# 2026-11-18 z42 0.7.0 / 豆包云主机

## 机器与工具链

- 豆包云主机：Linux x64，4 vCPU，内存 8GB，Ubuntu 22.04（glibc 2.35 + 自带 glibc 2.39 loader，见 `../../NOTES.md`）
- `z42 0.7.0 (linux-x64, 2026-11-15)`，`z42c build --release --opt all`
- Go 对照：`go1.23.0`，`GOMAXPROCS=4`，同机同参数
- seed 1234，40 人/房，`--spin-us 1000`

**这台是 4 vCPU 云主机，和 `archive/2026-08-13-*`（Mac Mini M4 10 核 / 12 核本机）不能横比绝对值。**

## 文件

| 文件 | 内容 |
|---|---|
| `matrix_z42.jsonl` | 8 格短矩阵：1/10/50/100 房 × arena/naive，600 tick，medium |
| `long_100_high.json` | 100 房，2400 tick（2 分钟），high，arena |

## 摘要

- 8 格 `world_hash` / `damage_total` / `alive_players` 与同机 Go 全部一致。
- 2 分钟浸泡：100 房 high，`world_hash=b1cb49ea9f80b211`、伤害 3890134、存活 1437，与 Go 一致；lag p50 1.38ms / p99 3.5ms / p999 10.7ms / max 45.4ms，超 50ms 0 次（max 已经很接近预算）。
- 计算 p50 90µs（Go 6µs），p99 1.46ms（Go 16µs）；`compute_max` 25ms 是一次 GC/JIT 级暂停。
- RSS 46MB（Go 12MB），CPU 43.8s（Go 2.4s，含 z42 的忙等与 JIT）。

## Go 对照（同机，本目录未入库）

| alloc | rooms | ticks | lag p50 | lag p99 | lag max |
|---|---|---|---|---|---|
| arena | 1 | 600 | 0.57ms | 1.07ms | 1.11ms |
| arena | 10 | 600 | 0.61ms | 1.19ms | 7.8ms |
| arena | 50 | 600 | 0.65ms | 1.19ms | 1.53ms |
| arena | 100 | 600 | 0.76ms | 1.39ms | 1.85ms |
| naive | 100 | 600 | 1.02ms | 2.10ms | 2.96ms |
| arena | 100 | 2400 | 0.75ms | 1.32ms | 4.07ms |
