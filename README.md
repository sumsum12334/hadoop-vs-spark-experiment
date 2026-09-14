# Hadoop MapReduce vs Spark — Experimental Comparison (design v4)

**Course:** CSIT6000U Independent Study  
**Student:** Polly Leung  
**Path:** `C:\git\dev`  
**Stack:** Docker Compose single-node · shared HDFS · Hadoop Streaming (Python) · PySpark

## Research story

| Condition | Expectation |
|---|---|
| `high_ram` (~8GB) + W3 (PageRank-lite K=5, Spark **cache**) | Spark wins (largest gap) |
| `high_ram` + W1/W2 | Spark often faster, smaller gap |
| `low_ram` (~1.5–2GB) + large single-pass W1 | MapReduce competitive or **faster** |

Same CPU both profiles; **only memory caps change**. Both engines see the same HDFS inputs.

## Layout

```
dev/
  docker-compose.yml
  .env.high_ram / .env.low_ram
  docker/           # hadoop.env, spark-defaults.conf
  jobs/mapreduce/   # W1/W2/W3 Python Streaming
  jobs/spark/       # W1/W2/W3 PySpark (W3 uses cache)
  scripts/          # generate_data, run_experiment, plot_results, *.ps1/*.sh
  data/             # generated (gitignored)
  results/results.csv
  README.md
```

## Prerequisites (Windows + Docker Desktop)

1. Docker Desktop running (Linux containers / WSL2 backend recommended)
2. Python 3.10+ on the host (for generators / runner / plots)
3. Enough disk for L (~5GB text + ~5GB graph) plus HDFS replicas volume
4. From PowerShell, `cd C:\git\dev`

Optional: `pip install -r requirements.txt` for plots.

## 1) Validate Compose

```powershell
cd C:\git\dev
docker compose --env-file .env.high_ram config
docker compose --env-file .env.low_ram config
```

```bash
docker compose --env-file .env.high_ram config
```

## 2) Start cluster (pick one RAM profile)

**PowerShell:**

```powershell
.\scripts\compose_up.ps1 -Profile high_ram
# later, for low-RAM matrix cells:
.\scripts\compose_up.ps1 -Profile low_ram
```

**bash:**

```bash
./scripts/compose_up.sh high_ram
```

UIs:

- HDFS NameNode: http://localhost:9870  
- YARN: http://localhost:8088  
- Spark: http://localhost:8080  

## 3) Generate data

```powershell
# Smoke only
python .\scripts\generate_data.py --sizes S

# Reporting sizes
python .\scripts\generate_data.py --sizes M,L
```

- Text → `data/text/size_{S,M,L}.txt` (W1/W2)  
- Graph → `data/graph/size_{S,M,L}.edges` (W3)  
Runner uploads to HDFS under `/input/text/...` and `/input/graph/...`.

## 4) Smoke (W1 / S)

```powershell
.\scripts\run_smoke.ps1
```

```bash
./scripts/run_smoke.sh
```

Or manually:

```powershell
.\scripts\compose_up.ps1 -Profile high_ram
python .\scripts\generate_data.py --sizes S
python .\scripts\run_experiment.py --condition high_ram --workloads W1 --sizes S --engines mapreduce,spark --trials 1
```

## 5) MVP matrix

`high_ram` + `low_ram` × **W1+W3** × **M+L** × **3 trials**, then W2 + plots:

```powershell
.\scripts\run_mvp.ps1
```

```bash
./scripts/run_mvp.sh
```

Partial run example:

```powershell
.\scripts\compose_up.ps1 -Profile low_ram
python .\scripts\run_experiment.py --condition low_ram --workloads W1,W3 --sizes M,L --engines mapreduce,spark --trials 3
```

## 6) Plots

```powershell
pip install -r requirements.txt
python .\scripts\plot_results.py
```

Figures land in `results/figures/`.

## results.csv columns (exact)

```text
condition,engine,workload,size,trial,wall_sec,throughput_MBps,peak_mem_mb,peak_cpu_pct,ok,notes
```

- **wall_sec:** submit → process exit (script timer)  
- **peak_mem_mb / peak_cpu_pct:** best-effort sum of `docker stats` samples across cluster containers during the trial — **approximate**, not cgroup-perfect  
- **ok=false** on non-zero exit / timeout; OOM-ish messages recorded in `notes` (fail soft)

**Do not invent numbers.** Empty data rows until real runs complete.

## Workloads

| ID | What | Notes |
|---|---|---|
| W1 | WordCount | Identical tokenization MR ↔ Spark |
| W2 | Top-N (N=100) after count | MR: WC then 1-reducer top-N; Spark: `takeOrdered` |
| W3 | PageRank-lite K=5 | Spark **caches** adjacency; MR re-runs full jobs per iteration |

Tokenization (W1/W2): lowercase; split on non-alphanumeric; drop empties. See `jobs/TOKENIZATION.md`.

## Fairness checklist

- [ ] Same HDFS input paths for both engines  
- [ ] Profile mem caps applied to **all** services via `MEM_LIMIT`  
- [ ] Clear `/output/...` each trial (runner does this)  
- [ ] Record host CPU/RAM, Docker Desktop version, image tags in the report  
- [ ] W3 Spark cache documented  

## Tear down

```powershell
docker compose --env-file .env.high_ram down
# volumes (destroys HDFS data):
docker compose --env-file .env.high_ram down -v
```

## Threats to validity (for the report)

- Single-node Docker ≠ multi-rack cluster network  
- Python Hadoop Streaming slower than native Java MR  
- `docker stats` peaks are sampled approximations  
- Default YARN/Spark tuning; not vendor-tuned  
- Synthetic data, not production corpora  

## MVP implementation order (status)

1. Compose + HDFS — **implemented**  
2. Smoke W1/S — **scripts ready** (`run_smoke.ps1`)  
3. high+low × W1+W3 × M+L × 3 — **`run_mvp.ps1`**  
4. W2 + plots — **included in MVP scripts**  


## Staging note (agents)

Authoritative tree for handoff also lives on the Cursor box at `/workspace/dev` and as `/workspace/hadoop-spark-compare-dev.tar.gz` if `C:\git\dev` could not be written directly from a sand executor (no `machineId` routing). Copy/extract onto Polly's Windows machine, then run the PowerShell steps above.
