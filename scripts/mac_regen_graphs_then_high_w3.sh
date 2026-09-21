#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p results
LOG="$ROOT/results/mac_regen_and_high_w3.out.log"
exec > >(tee -a "$LOG") 2>&1
echo "=== $(date) regen full graphs (same seed as Windows) then high_ram W3 ==="
echo $$ > "$ROOT/results/mac_high_ram_W3.pid"

echo "=== generate_data --sizes M,L --graph-only --force ==="
python3 scripts/generate_data.py --sizes M,L --graph-only --force
echo "=== graph sizes after gen ==="
ls -lah data/graph/
wc -l data/graph/size_*.edges
cat data/graph/size_M.meta data/graph/size_L.meta

# Sanity: L should be ~200M lines (+header), file ~3GB
lines=$(wc -l < data/graph/size_L.edges | tr -d ' ')
if [ "$lines" -lt 150000000 ]; then
  echo "FATAL: size_L.edges still incomplete (lines=$lines); abort"
  exit 1
fi

chmod +x scripts/*.sh
echo "=== compose_up high_ram (MEM_LIMIT=40g) ==="
./scripts/compose_up.sh high_ram

echo "=== run_experiment high_ram W3 ==="
python3 scripts/run_experiment.py \
  --condition high_ram --workloads W3 --sizes S,M,L \
  --engines mapreduce,spark --trials 3 \
  --results results/results_high_ram_W3_mac.csv

echo "=== $(date) DONE high_ram W3 with full graphs ==="
echo "PING_USER_HIGH_RAM_W3_MAC_FULLGRAPH_DONE"
