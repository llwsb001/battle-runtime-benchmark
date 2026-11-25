# 2026-11-25 skynet / 豆包云主机

## 机器与工具链

- 豆包云主机：Linux x64，4 vCPU，8GB，Ubuntu 22.04
- skynet `a2c00da`（2026-11-24），`make -j4 linux`，自带 Lua 5.5
- Go 对照：`go1.23.0`，`GOMAXPROCS=4`，同机同参数
- seed 1234，40 人/房，medium
- 默认 4 worker；1000 房另有 8 worker 版本

## 文件

| 文件 | 内容 |
|---|---|
| `matrix_skynet.jsonl` | 8 格：1/10/50/100 房 × arena/naive，600 tick，medium，4 worker |
| `rooms_1000_threads4.json` | 1000 房，600 tick，medium，arena，4 worker |
| `rooms_1000_threads8.json` | 同上，8 worker |

## 摘要

- 8 格 `world_hash` / `damage_total` / `alive_players` 与同机 Go 全部一致。
- 1–100 房均 0 次超 50ms；100 房 arena lag p99 8.9ms、compute p99 159µs。
- 1000 房 4 worker：lag p99 82.4ms、超 50ms 12263 次（600k tick 的 2%）、compute p99 253µs、RSS 146MB、CPU 68.4s。
- 1000 房 8 worker：lag p99 32.4ms、超 50ms 1177 次（0.2%）、无 >100ms、CPU 66.7s。
- Go 1000 房：lag p99 2.64ms、0 次超预算、CPU 3.69s。

## Go 对照（同机，本目录未入库）

| alloc | rooms | lag p50 | lag p99 | lag max | CPU |
|---|---|---|---|---|---|
| arena | 1 | 0.58ms | 1.07ms | 3.3ms | 0.04s |
| arena | 10 | 0.61ms | 1.13ms | 1.7ms | 0.11s |
| arena | 50 | 0.67ms | 1.18ms | 1.4ms | 0.26s |
| arena | 100 | 0.71ms | 1.82ms | 6.2ms | 0.49s |
| naive | 100 | 0.72ms | 1.40ms | 1.8ms | 0.67s |
| arena | 1000 | 1.52ms | 2.64ms | 3.58ms | 3.69s |
