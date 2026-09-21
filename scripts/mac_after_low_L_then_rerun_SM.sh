#!/usr/bin/env bash
set -uo pipefail
ROOT="/Users/polly.leung/git/dev/hadoop-vs-spark-experiment"
LOG="$ROOT/results/mac_rerun_SM_low_ram.out.log"
cd "$ROOT"
exec > >(tee -a "$LOG") 2>&1
echo "=== $(date) wait low_ram L matrix finish, then upload S/M and re-run S/M ==="
echo $$ > "$ROOT/results/mac_rerun_SM.pid"

# Wait until original run_experiment for low_ram W3 is gone
while pgrep -f 'run_experiment.py --condition low_ram --workloads W3' >/dev/null 2>&1; do
  echo "$(date) still waiting run_experiment low_ram W3..."
  sleep 60
done
echo "$(date) run_experiment exited"

# Also require L mapreduce has at least 1 successful long trial (or 3 L mr rows with wall>100)
python3 - <<'PY'
import csv, time
from pathlib import Path
p=Path("/Users/polly.leung/git/dev/hadoop-vs-spark-experiment/results/results_low_ram_W3_mac.csv")
# brief settle
time.sleep(2)
rows=list(csv.DictReader(p.open())) if p.exists() else []
l_mr=[r for r in rows if r.get("engine")=="mapreduce" and r.get("size")=="L" and float(r.get("wall_sec") or 0)>1000]
l_sp=[r for r in rows if r.get("engine")=="spark" and r.get("size")=="L"]
print(f"L_MR_long={len(l_mr)} L_Spark_rows={len(l_sp)}")
PY

echo "=== $(date) uploading S and M graphs to HDFS ==="
python3 - <<'PY'
import subprocess, os
ROOT="/Users/polly.leung/git/dev/hadoop-vs-spark-experiment"
subprocess.check_call(["docker","exec","hs-namenode","hdfs","dfs","-mkdir","-p","/input/graph"])
for label in ("S","M"):
  local=f"{ROOT}/data/graph/size_{label}.edges"
  assert os.path.exists(local), local
  sz=os.path.getsize(local)
  print(f"local {label}", sz)
  # remove old if any
  subprocess.call(["docker","exec","hs-namenode","hdfs","dfs","-rm","-f",f"/input/graph/size_{label}.edges"])
  subprocess.check_call(["docker","cp", local, f"hs-namenode:/tmp/size_{label}.edges"])
  subprocess.check_call(["docker","exec","hs-namenode","hdfs","dfs","-put","-f",f"/tmp/size_{label}.edges",f"/input/graph/size_{label}.edges"])
  subprocess.call(["docker","exec","hs-namenode","rm","-f",f"/tmp/size_{label}.edges"])
print(subprocess.check_output(["docker","exec","hs-namenode","hdfs","dfs","-du","-h","/input/graph"], text=True))
PY

echo "=== $(date) cleaning short-fail S/M rows from low_ram CSV (keep L + any long runs) ==="
python3 - <<'PY'
import csv
from pathlib import Path
p=Path("/Users/polly.leung/git/dev/hadoop-vs-spark-experiment/results/results_low_ram_W3_mac.csv")
bak=p.with_suffix(".csv.bak_before_SM_rerun")
rows=list(csv.DictReader(p.open()))
fields=list(csv.DictReader(p.open()).fieldnames) if False else None
with p.open() as f:
  reader=csv.DictReader(f)
  fields=reader.fieldnames
  rows=list(reader)
bak.write_text(p.read_text())
kept=[]
dropped=0
for r in rows:
  eng=r.get("engine"); size=r.get("size"); wall=float(r.get("wall_sec") or 0); ok=r.get("ok")
  # drop S/M short fails (missing-input artifacts)
  if size in ("S","M") and wall < 60:
    dropped+=1
    continue
  kept.append(r)
with p.open("w", newline="") as f:
  w=csv.DictWriter(f, fieldnames=fields)
  w.writeheader(); w.writerows(kept)
print(f"backup={bak} dropped_SM_short={dropped} kept={len(kept)}")
PY

echo "=== $(date) re-run low_ram W3 S,M only (MR+Spark ×3), skip-upload ==="
python3 scripts/run_experiment.py \
  --condition low_ram --workloads W3 --sizes S,M \
  --engines mapreduce,spark --trials 3 \
  --skip-upload \
  --results results/results_low_ram_W3_mac.csv

echo "PING_USER_LOW_RAM_SM_RERUN_DONE"
echo "=== $(date) S/M rerun finished ==="
