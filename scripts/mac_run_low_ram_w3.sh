#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p results
LOG="$ROOT/results/mac_low_ram_W3.out.log"
exec > >(tee -a "$LOG") 2>&1
echo "=== $(date) mac_run_low_ram_w3.sh START (pid $$) ==="
echo $$ > "$ROOT/results/mac_low_ram_W3.pid"
docker info --format "MemTotal={{.MemTotal}} NCPU={{.NCPU}}"
echo "=== compose_up low_ram ==="
chmod +x scripts/*.sh
./scripts/compose_up.sh low_ram
echo "=== run_experiment W3 low_ram ==="
python3 scripts/run_experiment.py \
  --condition low_ram --workloads W3 --sizes S,M,L \
  --engines mapreduce,spark --trials 3 \
  --results results/results_low_ram_W3_mac.csv
echo "=== $(date) DONE low_ram W3 ==="
echo "PING_USER_LOW_RAM_W3_MAC_DONE"
