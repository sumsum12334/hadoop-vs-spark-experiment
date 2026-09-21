#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p results
LOG="$ROOT/results/mac_high_ram_W3.out.log"
exec > >(tee -a "$LOG") 2>&1
echo "=== $(date) mac_run_high_ram_w3.sh START (pid $$) ==="
echo $$ > "$ROOT/results/mac_high_ram_W3.pid"
docker info --format "MemTotal={{.MemTotal}} NCPU={{.NCPU}}"
ls -lah data/graph/

echo "=== pull images (up to 3 attempts) ==="
ok=0
for attempt in 1 2 3; do
  echo "--- pull attempt $attempt ---"
  if docker compose --env-file .env.high_ram pull; then
    ok=1
    echo "pull OK"
    break
  fi
  echo "pull failed attempt $attempt; sleep 30"
  sleep 30
done
if [ "$ok" != 1 ]; then
  echo "FATAL: pull failed"
  exit 1
fi
docker images | grep -E 'hadoop|spark|REPOSITORY' || true

chmod +x scripts/*.sh
echo "=== compose_up high_ram ==="
./scripts/compose_up.sh high_ram

echo "=== run_experiment W3 ==="
python3 scripts/run_experiment.py \
  --condition high_ram --workloads W3 --sizes S,M,L \
  --engines mapreduce,spark --trials 3 \
  --results results/results_high_ram_W3_mac.csv

echo "=== $(date) DONE high_ram W3 ==="
echo "PING_USER_HIGH_RAM_W3_MAC_DONE"
