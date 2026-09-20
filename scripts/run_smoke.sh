#!/usr/bin/env bash
# Smoke: bring up high_ram, generate S, run W1 × both engines × 1 trial
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
"$ROOT/scripts/compose_up.sh" high_ram
python3 "$ROOT/scripts/generate_data.py" --sizes S
python3 "$ROOT/scripts/run_experiment.py" \
  --condition high_ram --workloads W1 --sizes S --engines mapreduce,spark --trials 1
echo "Smoke complete. See results/results.csv"
