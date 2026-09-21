#!/usr/bin/env bash
# Live progress for Mac high_ram W3 (Ctrl+C closes this window only)
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
echo "Hadoop MVP live progress (Mac) — Ctrl+C closes this window only"
echo "Project: $ROOT"
echo "Also: results/mac_progress_live.txt  |  chat ping every 15m"
echo

while true; do
  ts=$(date '+%H:%M:%S')
  echo "======== $ts ========"

  if pgrep -f 'run_experiment\.py' >/dev/null 2>&1; then
    echo "Runner: alive (run_experiment)"
    ps -eo command | grep -E '[r]un_experiment\.py' | head -1 | fold -s -w 100 | head -2
  elif pgrep -f 'generate_data\.py' >/dev/null 2>&1; then
    echo "Phase: generate_data running"
  elif [ -f results/mac_high_ram_W3.pid ] && kill -0 "$(cat results/mac_high_ram_W3.pid)" 2>/dev/null; then
    echo "Phase: pipeline shell alive (pid $(cat results/mac_high_ram_W3.pid))"
  else
    echo "Runner: NOT running"
  fi

  if pgrep -f 'spark-submit' >/dev/null 2>&1; then
    echo "Spark-submit: RUNNING"
  else
    echo "Spark-submit: idle"
  fi

  docker stats --no-stream --format '{{.Name}}|{{.CPUPerc}}|{{.MemUsage}}' 2>/dev/null \
    | while IFS='|' read -r name cpu mem; do
        case "$name" in
          hs-*) printf '  %-22s CPU=%-8s MEM=%s\n' "$name" "$cpu" "$mem" ;;
        esac
      done

  yarn=$(docker exec hs-resourcemanager yarn application -list 2>/dev/null || true)
  if echo "$yarn" | grep -q 'application_'; then
    echo "$yarn" | grep 'application_' | head -5 | while read -r line; do echo "YARN: $line"; done
  else
    echo "YARN: no RUNNING app"
  fi

  for f in results/results_*_mac.csv; do
    [ -f "$f" ] || continue
    rows=$(($(wc -l < "$f") - 1))
    mtime=$(stat -f '%Sm' -t '%H:%M:%S' "$f" 2>/dev/null || true)
    echo "CSV $(basename "$f"): ${rows} rows (mtime $mtime)"
    tail -n +2 "$f" | tail -3 | while IFS= read -r row; do echo "  $row" | cut -c1-120; done
  done
  if ! ls results/results_*_mac.csv >/dev/null 2>&1; then
    echo "CSV mac: not created yet"
  fi

  if [ -f results/mac_high_ram_W3.out.log ]; then
    echo "--- log tail ---"
    tail -6 results/mac_high_ram_W3.out.log
  fi
  if [ -f data/graph/size_L.edges ]; then
    ls -lh data/graph/size_L.edges | awk '{print "graph L:", $5}'
  else
    echo "graph L: MISSING / generating"
    ls -lh data/graph/ 2>/dev/null | tail -5
  fi
  echo
  sleep 10
done
