#!/usr/bin/env bash
# Standalone z42 matrix runner (does not touch ../scripts/*).
#
#   ROOMS="1 10 50 100" ALLOCS="arena naive" WORKLOAD=medium TICKS=2400 ./bench_matrix.sh
#
# Writes results/matrix_z42.jsonl (git-ignored, same as the other languages' results/).
set -euo pipefail
cd "$(dirname "$0")"

ROOMS="${ROOMS:-1 10 50 100}"
ALLOCS="${ALLOCS:-arena naive}"
WORKLOAD="${WORKLOAD:-medium}"
TICKS="${TICKS:-600}"
SEED="${SEED:-1234}"
PLAYERS="${PLAYERS:-40}"
SPIN_US="${SPIN_US:-1000}"
OUT="${OUT:-results/matrix_z42.jsonl}"

mkdir -p "$(dirname "$OUT")"
: > "$OUT"

for alloc in $ALLOCS; do
  for rooms in $ROOMS; do
    echo "== z42 rooms=$rooms alloc=$alloc workload=$WORKLOAD ticks=$TICKS" >&2
    ./run.sh --rooms "$rooms" --players "$PLAYERS" --ticks "$TICKS" \
      --seed "$SEED" --workload "$WORKLOAD" --alloc "$alloc" --spin-us "$SPIN_US" \
      | python3 -c 'import json,sys; json.dump(json.load(sys.stdin), sys.stdout); print()' \
      >> "$OUT"
  done
done

echo "wrote $OUT" >&2
