#!/usr/bin/env bash
# Build (release + all optimizations) and run the z42 battle binary.
# Usage: ./run.sh --rooms 1 --players 40 --ticks 200 --seed 1234 --workload medium --alloc arena
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v z42 >/dev/null 2>&1; then
  echo "z42 not found in PATH." >&2
  echo "Install: curl -fsSL https://z42-lang.github.io/z42/install-z42.sh | sh" >&2
  echo "Then:    export PATH=\"\$HOME/.z42:\$HOME/.z42/bin:\$PATH\"" >&2
  exit 1
fi

z42c build --release --opt all -q
exec z42 dist/z42-battle.zpkg -- "$@"
