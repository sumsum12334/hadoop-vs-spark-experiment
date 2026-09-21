#!/usr/bin/env bash
# MVP: high+low x W1+W3 x M+L x 3 trials (then W2 + plots)
# Results filenames encode env + workload: results_{condition}_{workload}.csv
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p "$ROOT/results"

python3 "$ROOT/scripts/generate_data.py" --sizes M,L

for cond in high_ram low_ram; do
  "$ROOT/scripts/compose_up.sh" "$cond"
  for wl in W1 W3; do
    out="$ROOT/results/results_${cond}_${wl}.csv"
    echo ">>> $cond $wl -> $out"
    python3 "$ROOT/scripts/run_experiment.py" \
      --condition "$cond" --workloads "$wl" --sizes M,L \
      --engines mapreduce,spark --trials 3 \
      --results "$out"
  done
done

for cond in high_ram low_ram; do
  "$ROOT/scripts/compose_up.sh" "$cond"
  wl=W2
  out="$ROOT/results/results_${cond}_${wl}.csv"
  echo ">>> $cond $wl -> $out"
  python3 "$ROOT/scripts/run_experiment.py" \
    --condition "$cond" --workloads "$wl" --sizes M,L \
    --engines mapreduce,spark --trials 3 \
    --results "$out"
done

python3 "$ROOT/scripts/merge_results.py"
python3 "$ROOT/scripts/plot_results.py" --csv "$ROOT/results/results_all.csv" || true
echo "MVP matrix complete. Per-file results under results/results_<env>_<workload>.csv"
