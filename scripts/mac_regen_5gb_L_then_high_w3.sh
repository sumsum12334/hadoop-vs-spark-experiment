#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p results
LOG="$ROOT/results/mac_regen_5gb_and_high_w3.out.log"
exec > >(tee -a "$LOG") 2>&1
echo "=== $(date) regen L ~5GiB (360M edges) then high_ram W3 ==="
echo $$ > "$ROOT/results/mac_high_ram_W3.pid"

echo "=== generate_data --sizes L --graph-only --force ==="
python3 scripts/generate_data.py --sizes L --graph-only --force
ls -lah data/graph/
wc -l data/graph/size_L.edges
cat data/graph/size_L.meta
python3 - <<'PY'
from pathlib import Path
sz=Path('data/graph/size_L.edges').stat().st_size
print(f'size_L.edges bytes={sz} GiB={sz/1024**3:.3f}')
if sz < 4.5 * 1024**3:
    raise SystemExit(f'FATAL: L graph only {sz/1024**3:.2f} GiB, want ~5GiB')
print('L size OK')
PY

chmod +x scripts/*.sh
echo "=== compose_up high_ram ==="
./scripts/compose_up.sh high_ram
echo "=== run_experiment high_ram W3 ==="
python3 scripts/run_experiment.py \
  --condition high_ram --workloads W3 --sizes S,M,L \
  --engines mapreduce,spark --trials 3 \
  --results results/results_high_ram_W3_mac.csv
echo "=== $(date) DONE high_ram W3 with ~5GiB L ==="
echo "PING_USER_HIGH_RAM_W3_MAC_5GB_DONE"
