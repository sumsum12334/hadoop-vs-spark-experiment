#!/usr/bin/env bash
set -euo pipefail
ROOT="/Users/polly.leung/git/dev/hadoop-vs-spark-experiment"
LOG="$ROOT/results/mac_spark_L_trial3.out.log"
cd "$ROOT"
exec > >(tee -a "$LOG") 2>&1
echo "=== $(date) Spark L trial3 only (clean post-reboot) ==="
echo $$ > "$ROOT/results/mac_spark_L_trial3.pid"
set -a; source .env.high_ram; set +a
echo "RESULTS $ROOT/results/results_high_ram_W3_mac.csv"
echo "SPARK_DRIVER_MEMORY $SPARK_DRIVER_MEMORY"
echo "SPARK_EXECUTOR_MEMORY $SPARK_EXECUTOR_MEMORY"

for i in $(seq 1 60); do
  if docker exec hs-spark getent hosts namenode >/dev/null 2>&1 \
     && docker exec hs-namenode hdfs dfs -du -s /input/graph/size_L.edges >/dev/null 2>&1; then
    echo "hdfs_ready try=$i"
    break
  fi
  echo "wait_hdfs $i"; sleep 5
done
docker exec hs-namenode hdfs dfs -du -h /input/graph/size_L.edges
docker exec hs-namenode hdfs dfs -rm -r -f /output/high_ram/spark/W3/L/trial3 || true
docker exec hs-spark bash -lc 'pkill -f SparkSubmit || true; pkill -f w3_pagerank || true' || true
sleep 2
n=$(docker exec hs-spark bash -lc 'pgrep -c SparkSubmit || echo 0')
echo "SparkSubmit_count_before=$n"

python3 - <<'PY'
import csv, os, subprocess, time, re
from pathlib import Path
ROOT=Path("/Users/polly.leung/git/dev/hadoop-vs-spark-experiment")
env={}
for line in (ROOT/".env.high_ram").read_text().splitlines():
  if "=" in line and not line.strip().startswith("#"):
    k,v=line.split("=",1); env[k.strip()]=v.strip()
drv=env.get("SPARK_DRIVER_MEMORY","24g")
exe=env.get("SPARK_EXECUTOR_MEMORY","24g")
print(f"spark mem from .env.high_ram: driver={drv} executor={exe}")
cmd=[
  "docker","exec","hs-spark","spark-submit",
  "--master","local[*]",
  "--driver-memory", drv,
  "--conf", f"spark.executor.memory={exe}",
  "--conf","spark.hadoop.fs.defaultFS=hdfs://namenode:9000",
  "/jobs/spark/w3_pagerank.py",
  "--input","/input/graph/size_L.edges",
  "--output","/output/high_ram/spark/W3/L/trial3",
  "--iterations","5",
]
t0=time.time()
peak_mem=0.0; peak_cpu=0.0
proc=subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
out_lines=[]
while True:
  line=proc.stdout.readline()
  if line:
    out_lines.append(line)
    if len(out_lines)%200==0:
      print(line.rstrip())
  if proc.poll() is not None:
    rest=proc.stdout.read()
    if rest: out_lines.append(rest)
    break
  try:
    st=subprocess.check_output(["docker","stats","--no-stream","--format","{{.MemUsage}}|{{.CPUPerc}}","hs-spark"], text=True).strip()
    mem_s,cpu_s=st.split("|")
    used=mem_s.split("/")[0].strip()
    m=re.match(r"([0-9.]+)([GMK]i?B)", used.replace(" ",""))
    if m:
      val=float(m.group(1)); unit=m.group(2)
      mb=val*(1024 if unit.startswith("G") else (1 if unit.startswith("M") else 1/1024))
      peak_mem=max(peak_mem, mb)
    peak_cpu=max(peak_cpu, float(cpu_s.strip().rstrip("%")))
  except Exception:
    pass
  time.sleep(5)
rc=proc.returncode
wall=time.time()-t0
text="".join(out_lines)
ok = rc==0
notes=""
if not ok:
  notes=("exit=%s|"%rc)+re.sub(r"\s+"," ", text[-800])
try:
  b=int(subprocess.check_output(["docker","exec","hs-namenode","hdfs","dfs","-du","-s","/input/graph/size_L.edges"], text=True).split()[0])
except Exception:
  b=int((ROOT/"data/graph/size_L.edges").stat().st_size)
thr=(b/1e6)/wall if wall>0 else 0
row={
  "condition":"high_ram","engine":"spark","workload":"W3","size":"L","trial":"3",
  "wall_sec":f"{wall:.3f}","throughput_MBps":f"{thr:.4f}",
  "peak_mem_mb":f"{peak_mem:.1f}","peak_cpu_pct":f"{peak_cpu:.1f}",
  "ok":"true" if ok else "false","notes":notes,
}
csv_path=ROOT/"results/results_high_ram_W3_mac.csv"
with csv_path.open() as f:
  reader=csv.DictReader(f); fields=reader.fieldnames; rows=list(reader)
rows=[r for r in rows if not (r.get("engine")=="spark" and r.get("size")=="L" and str(r.get("trial"))=="3")]
rows.append(row)
with csv_path.open("w", newline="") as f:
  w=csv.DictWriter(f, fieldnames=fields); w.writeheader(); w.writerows(rows)
print("ROW", row)
print("DONE_TRIAL3", row)
print("PING_USER_SPARK_L_TRIAL3_DONE")
raise SystemExit(0 if ok else 1)
PY
echo "=== $(date) finished spark L trial3 ==="
