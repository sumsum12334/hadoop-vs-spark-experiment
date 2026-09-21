#!/usr/bin/env bash
ROOT="/Users/polly.leung/git/dev/hadoop-vs-spark-experiment"
CSV="$ROOT/results/results_high_ram_W3_mac.csv"
LOG="$ROOT/results/stop_after_spark_L_t2.log"
echo "=== $(date) watch for spark L trial2 then stop ===" | tee -a "$LOG"
while true; do
  if python3 - <<'PY'
import csv
from pathlib import Path
p=Path("/Users/polly.leung/git/dev/hadoop-vs-spark-experiment/results/results_high_ram_W3_mac.csv")
if not p.exists():
  raise SystemExit(1)
rows=list(csv.DictReader(p.open()))
ok=any(r.get("engine")=="spark" and r.get("size")=="L" and str(r.get("trial"))=="2" and r.get("ok")=="true" for r in rows)
raise SystemExit(0 if ok else 1)
PY
  then
    echo "$(date) spark L trial2 present — stopping runners" | tee -a "$LOG"
    # give a moment for CSV flush
    sleep 2
    pkill -f 'run_experiment.py' 2>/dev/null || true
    sleep 1
    # if trial3 already started spark-submit, kill it too
    pkill -f 'spark-submit.*W3/L/trial3' 2>/dev/null || true
    pkill -f 'mac_regen_5gb_L_then_high_w3' 2>/dev/null || true
    echo "PING_USER_STOPPED_AFTER_SPARK_L_TRIAL2" | tee -a "$LOG"
    echo "$(date) stopped" | tee -a "$LOG"
    exit 0
  fi
  sleep 15
done
