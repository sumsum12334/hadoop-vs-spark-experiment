#!/usr/bin/env bash
set -uo pipefail
ROOT="/Users/polly.leung/git/dev/hadoop-vs-spark-experiment"
LOG="$ROOT/results/mac_chain_low_ram_W3.out.log"
cd "$ROOT"
exec > >(tee -a "$LOG") 2>&1
echo "=== $(date) wait CLEAN high_ram Spark L trial3 then low_ram ==="
echo $$ > "$ROOT/results/mac_low_ram_W3.pid"
while true; do
  if python3 - <<'PY'
import csv
from pathlib import Path
p=Path("/Users/polly.leung/git/dev/hadoop-vs-spark-experiment/results/results_high_ram_W3_mac.csv")
rows=list(csv.DictReader(p.open())) if p.exists() else []
ok=any(
  r.get("engine")=="spark" and r.get("size")=="L" and str(r.get("trial"))=="3"
  and r.get("ok")=="true" and float(r.get("wall_sec") or 0) > 1000
  and "dual_sparksubmit" not in (r.get("notes") or "")
  and "UnknownHostException" not in (r.get("notes") or "")
  for r in rows
)
raise SystemExit(0 if ok else 1)
PY
  then echo "$(date) clean trial3 found"; break; fi
  sleep 30
done
echo "=== $(date) starting low_ram W3 ==="
./scripts/compose_up.sh low_ram
python3 - <<'PY'
import subprocess
ROOT="/Users/polly.leung/git/dev/hadoop-vs-spark-experiment"
local=f"{ROOT}/data/graph/size_L.edges"
try:
  b=int(subprocess.check_output(["docker","exec","hs-namenode","hdfs","dfs","-du","-s","/input/graph/size_L.edges"], text=True, stderr=subprocess.DEVNULL).split()[0])
except Exception:
  b=0
print("HDFS_L", b)
if b < int(4.5*1024**3):
  subprocess.call(["docker","exec","hs-namenode","hdfs","dfs","-rm","-f","/input/graph/size_L.edges"])
  subprocess.check_call(["docker","exec","hs-namenode","hdfs","dfs","-mkdir","-p","/input/graph"])
  subprocess.check_call(["docker","cp", local, "hs-namenode:/tmp/size_L.edges"])
  subprocess.check_call(["docker","exec","hs-namenode","hdfs","dfs","-put","-f","/tmp/size_L.edges","/input/graph/size_L.edges"])
  subprocess.call(["docker","exec","hs-namenode","rm","-f","/tmp/size_L.edges"])
print(subprocess.check_output(["docker","exec","hs-namenode","hdfs","dfs","-du","-h","/input/graph/size_L.edges"], text=True))
PY
python3 scripts/run_experiment.py \
  --condition low_ram --workloads W3 --sizes S,M,L \
  --engines mapreduce,spark --trials 3 \
  --skip-upload \
  --results results/results_low_ram_W3_mac.csv
echo "PING_USER_LOW_RAM_W3_MAC_DONE"
