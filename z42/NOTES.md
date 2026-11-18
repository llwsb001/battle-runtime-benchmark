# z42 环境与限制（本机实测）

## 工具链

- `z42 0.7.0 (linux-x64, 2026-11-15)`，官方安装脚本装到 `~/.z42`。
- `PATH="$HOME/.z42:$HOME/.z42/bin:$PATH"`；安装器写 `~/.profile`，已有 shell 需手动 export。
- 编译：`z42c build --release --opt all`；运行：`z42 dist/z42-battle.zpkg -- <参数>`。
- `z42 run --mode jit|interp` 用于临时调试，程序参数必须放在 `--` 之后。

## GLIBC 2.39（Ubuntu 22.04 才有这个问题）

0.7.0 的所有二进制（`z42` / `z42vm` / `z42c` …）都链 GLIBC 2.39，而 Ubuntu 22.04 是 2.35，直接跑报：

```
weak version `GLIBC_2.39' not found
libz42.so: dlopen failed
```

`--library-path` 单独指过去不行：`z42` 是 apphost，会 spawn `z42vm` 子进程，loader 路径会丢。做法是给二进制换 interpreter + rpath：

```bash
# 从镜像站取 2.39 的 libc6 包（archive.ubuntu.com 在本机被重置，清华镜像可用）
curl -fL -o /tmp/libc6_2.39.deb \
  https://mirrors.tuna.tsinghua.edu.cn/ubuntu/pool/main/g/glibc/libc6_2.39-0ubuntu8.12_amd64.deb
mkdir -p ~/.z42/glibc239 && dpkg-deb -x /tmp/libc6_2.39.deb ~/.z42/glibc239

L=~/.z42/glibc239/usr/lib/x86_64-linux-gnu
for b in ~/.z42/z42 ~/.z42/bin/z42b ~/.z42/bin/z42c ~/.z42/bin/z42d ~/.z42/bin/z42i ~/.z42/bin/z42vm; do
  cp "$b" "$b.orig-glibc235"
  patchelf --set-interpreter "$L/ld-linux-x86-64.so.2" --set-rpath "$L" "$b"
done
```

这是本机 workaround，不属于仓库逻辑；换 Ubuntu 24.04 或等官方出 glibc 2.35 构建就不需要。

## 语言侧限制（0.7.0）

- 没有 `i32`/`u64` 这类短类型名，用 `int`/`long`/`uint`/`ulong` 等关键字。
- `ulong` 的 `^` / `>>` 在 0.7.0 编译不过（会被推断成 `int` 报 E0439），所以内核统一用 `long` + `LShr`。
- `long` 的 `>>` 是算术右移；`%` 的余数跟被除数走（`-5 % 7 == -5`），无符号语义要自己折。
- `out` 是关键字，不能当变量名。
- `Thread.Sleep` **只有毫秒精度**（本机实测 1ms→1.056ms、5ms→5.06ms、49ms→49.09ms），所以 `WaitUntil` 用「睡到 due 前 N µs + 忙等」，默认 `--spin-us 1000`；`--spin-us 0` 会退化成纯 Sleep，基线 lag 抬到毫秒级。
- 没有分配字节计数（`GC.GetTotalAllocatedBytes` 之类），`alloc_bytes` 只能写 0；`RuntimeStats.Counters()` 能给 `Allocations` / `MinorCollections` / `MajorCollections` / `JitMethodsCompiled` / `JitNativeFromInterp`。
- 线程 = OS 线程（`Thread.Start`），1000 房就是 1000 个线程 + 1ms 级 timer，扩展性和 Go 的 goroutine 不可直接类比。

## 语义对齐踩过的坑

1. **无符号取模折叠条件**：判断 `r < 0` 会漏掉「x 为负但整余」的情况（`unsigned(-10) % 10` 应为 6 而非 0），必须判 `x >= 0`。
2. **arena 槽位复用**：压缩后把活对象前移，尾部旧槽仍指向同一对象；按「槽位下标」复用会覆盖活对象，表现为 `world_hash`/`damage_total` 全错（proj 数 9 vs 8）。改成 free-list（死对象入池、spawn 出池、压缩后尾部置 null）后和 naive 完全一致。
3. **`Snap` 预分配**：arena 模式下 snapshot 对象必须每 tick 都 `new`（或首次预分配后复用），否则线程内写字段报 NullReference。

## 参考文档

- z42 仓库：<https://github.com/z42-lang/z42>
- 运行时审计（本文档的由来、JIT/GC/线程模型口径）：<https://github.com/z42-lang/z42/blob/main/docs/runtime-audit.md>
- 语言教程与 API：仓库内 `docs/learn/`、`docs/reference/`、`src/libraries/`
