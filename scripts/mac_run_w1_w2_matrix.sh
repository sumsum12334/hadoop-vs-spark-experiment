#!/usr/bin/env bash
set -uo pipefail
ROOT="/Users/polly.leung/git/dev/hadoop-vs-spark-experiment"
LOG="$ROOT/results/mac_w1_w2_matrix.out.log"
cd "$ROOT"
mkdir -p results
exec > >(tee -a "$LOG") 2>&1
echo "=== $(date) Mac W1+W2 matrix START ==="
echo $$ > "$ROOT/results/mac_w1_w2.pid"
chmod +x scripts/*.sh

run_one() {
  local cond="$1" wl="$2" results="$3" skip="$4"
  echo "=== $(date) START $cond $wl → $results (skip_upload=$skip) ==="
  local args=(python3 scripts/run_experiment.py
    --condition "$cond" --workloads "$wl" --sizes S,M,L
    --engines mapreduce,spark --trials 3
    --results "$results")
  if [ "$skip" = "1" ]; then
    args+=(--skip-upload)
  fi
  "${args[@]}"
  local rc=$?
  echo "=== $(date) DONE $cond $wl rc=$rc ==="
  return $rc
}

echo "=== compose_up high_ram ==="
./scripts/compose_up.sh high_ram

# First high_ram W1 uploads text (+ graph if missing)
run_one high_ram W1 results/results_high_ram_W1_mac.csv 0
run_one high_ram W2 results/results_high_ram_W2_mac.csv 1

echo "PING_USER_MAC_HIGH_RAM_W1_W2_DONE"

echo "=== compose_up low_ram ==="
./scripts/compose_up.sh low_ram

# After recreate, need upload again for text
run_one low_ram W1 results/results_low_ram_W1_mac.csv 0
run_one low_ram W2 results/results_low_ram_W2_mac.csv 1

echo "PING_USER_MAC_LOW_RAM_W1_W2_DONE"
echo "PING_USER_MAC_W1_W2_MATRIX_DONE"
echo "=== $(date) Mac W1+W2 matrix FINISHED ==="
