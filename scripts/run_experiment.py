#!/usr/bin/env python3
"""Experiment runner: env × workload × size × engine × trials -> results.csv

Measures wall clock; best-effort peak mem/cpu via `docker stats` sampling.
OOM / failures -> ok=false + notes (fail soft).

Examples:
  python scripts/run_experiment.py --condition high_ram --workloads W1 --sizes S --engines mapreduce,spark --trials 1
  python scripts/run_experiment.py --condition low_ram --workloads W1,W3 --sizes M,L --trials 3
"""
from __future__ import annotations

import argparse
import csv
import json
import os
import re
import subprocess
import sys
import threading
import time
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RESULTS = ROOT / "results" / "results.csv"
CSV_HEADER = [
    "condition", "engine", "workload", "size", "trial",
    "wall_sec", "throughput_MBps", "peak_mem_mb", "peak_cpu_pct",
    "ok", "notes",
]

HDFS_NN = "hdfs://namenode:9000"
CONTAINER_HADOOP = "hs-namenode"   # submit streaming via namenode (has hadoop CLI)
CONTAINER_NM = "hs-nodemanager"
CONTAINER_SPARK = "hs-spark"

SIZE_INPUT = {
    "S": {"text": "/input/text/size_S.txt", "graph": "/input/graph/size_S.edges", "bytes": 100 * 1024 * 1024},
    "M": {"text": "/input/text/size_M.txt", "graph": "/input/graph/size_M.edges", "bytes": 1 * 1024 * 1024 * 1024},
    "L": {"text": "/input/text/size_L.txt", "graph": "/input/graph/size_L.edges", "bytes": 5 * 1024 * 1024 * 1024},
}


def run(cmd, check=False, env=None, timeout=None):
    print("+", " ".join(cmd) if isinstance(cmd, list) else cmd)
    return subprocess.run(
        cmd, check=check, env=env, timeout=timeout,
        capture_output=True, text=True,
    )


def docker_exec(container: str, args: list[str], check=False, timeout=None):
    return run(["docker", "exec", container] + args, check=check, timeout=timeout)


def ensure_csv():
    RESULTS.parent.mkdir(parents=True, exist_ok=True)
    if not RESULTS.exists():
        with open(RESULTS, "w", newline="", encoding="utf-8") as f:
            csv.writer(f).writerow(CSV_HEADER)


def append_row(row: dict):
    ensure_csv()
    with open(RESULTS, "a", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=CSV_HEADER)
        w.writerow({k: row.get(k, "") for k in CSV_HEADER})


class DockerStatsSampler:
    """Best-effort peak mem/cpu across compose containers while a job runs."""

    def __init__(self, containers: list[str], interval: float = 1.0):
        self.containers = containers
        self.interval = interval
        self.peak_mem_mb = 0.0
        self.peak_cpu_pct = 0.0
        self._stop = threading.Event()
        self._thread = None
        self.error = None

    def start(self):
        self._thread = threading.Thread(target=self._loop, daemon=True)
        self._thread.start()

    def stop(self):
        self._stop.set()
        if self._thread:
            self._thread.join(timeout=5)

    def _loop(self):
        while not self._stop.is_set():
            try:
                proc = subprocess.run(
                    [
                        "docker", "stats", "--no-stream", "--format",
                        "{{.Name}},{{.CPUPerc}},{{.MemUsage}}",
                    ] + self.containers,
                    capture_output=True, text=True, timeout=15,
                )
                total_mem = 0.0
                total_cpu = 0.0
                for line in proc.stdout.splitlines():
                    parts = [p.strip() for p in line.split(",")]
                    if len(parts) < 3:
                        continue
                    cpu_s, mem_s = parts[1], parts[2]
                    cpu = float(cpu_s.replace("%", "") or 0)
                    # MemUsage like "1.2GiB / 8GiB"
                    used = mem_s.split("/")[0].strip()
                    total_mem += _parse_mem_mb(used)
                    total_cpu += cpu
                self.peak_mem_mb = max(self.peak_mem_mb, total_mem)
                self.peak_cpu_pct = max(self.peak_cpu_pct, total_cpu)
            except Exception as e:
                self.error = str(e)
            self._stop.wait(self.interval)


def _parse_mem_mb(s: str) -> float:
    s = s.strip()
    m = re.match(r"([0-9.]+)\s*([KMGTiB]+)", s, re.I)
    if not m:
        return 0.0
    val = float(m.group(1))
    unit = m.group(2).upper()
    if unit.startswith("G"):
        return val * 1024
    if unit.startswith("M"):
        return val
    if unit.startswith("K"):
        return val / 1024
    if unit.startswith("T"):
        return val * 1024 * 1024
    return val


def hdfs_rm(path: str):
    docker_exec(CONTAINER_HADOOP, ["hdfs", "dfs", "-rm", "-r", "-f", path])


def _host_path_for_container_data(local_rel: str) -> Path:
    """Map container path /data/... to host ROOT/data/... (Docker Desktop bind mounts flake on multi-GB hdfs put)."""
    p = local_rel.replace("\\", "/")
    if p.startswith("/data/"):
        return ROOT / "data" / Path(p[len("/data/"):])
    return Path(local_rel)


def hdfs_put_if_needed(local_rel: str, hdfs_path: str):
    """Upload local file into HDFS if missing.

    Uses `docker cp` into the namenode then `hdfs dfs -put` from container-local
    /tmp — direct put from a Windows bind-mount often fails with COPYING / bad datanode
    on multi-GB files under Docker Desktop.
    """
    check = docker_exec(CONTAINER_HADOOP, ["hdfs", "dfs", "-test", "-e", hdfs_path])
    if check.returncode == 0:
        print(f"[hdfs] exists {hdfs_path}")
        return
    parent = "/".join(hdfs_path.rstrip("/").split("/")[:-1]) or "/"
    docker_exec(CONTAINER_HADOOP, ["hdfs", "dfs", "-mkdir", "-p", parent])
    host = _host_path_for_container_data(local_rel)
    if not host.is_file():
        raise FileNotFoundError(f"local dataset missing: {host} (from {local_rel})")
    tmp_name = host.name
    tmp_in = f"/tmp/{tmp_name}"
    # Drop leftover lease/temp from a prior interrupted put (ignore errors).
    docker_exec(CONTAINER_HADOOP, ["hdfs", "dfs", "-rm", "-f", hdfs_path + "._COPYING_", hdfs_path])
    last = None
    for attempt in range(1, 4):
        print(f"[hdfs] docker cp {host} -> {CONTAINER_HADOOP}:{tmp_in} (attempt {attempt})")
        cp = run(["docker", "cp", str(host), f"{CONTAINER_HADOOP}:{tmp_in}"], timeout=6 * 3600)
        if cp.returncode != 0:
            last = cp
            print(f"[hdfs] docker cp failed: {(cp.stderr or cp.stdout or '')[:400]}")
            time.sleep(2)
            continue
        r = docker_exec(CONTAINER_HADOOP, ["hdfs", "dfs", "-put", "-f", tmp_in, hdfs_path], timeout=6 * 3600)
        last = r
        docker_exec(CONTAINER_HADOOP, ["rm", "-f", tmp_in])
        if r.returncode == 0:
            return
        print(f"[hdfs] put attempt {attempt} failed: {(r.stderr or r.stdout or '')[:400]}")
        docker_exec(CONTAINER_HADOOP, ["hdfs", "dfs", "-rm", "-f", hdfs_path + "._COPYING_", hdfs_path])
        time.sleep(2)
    raise RuntimeError(f"hdfs put failed: {last.stderr if last else 'unknown'}")


def upload_datasets(sizes: list[str]):
    for s in sizes:
        text_local = f"/data/text/size_{s}.txt"
        graph_local = f"/data/graph/size_{s}.edges"
        hdfs_put_if_needed(text_local, SIZE_INPUT[s]["text"])
        hdfs_put_if_needed(graph_local, SIZE_INPUT[s]["graph"])
        # Prefer actual HDFS size for throughput if available
        du = docker_exec(CONTAINER_HADOOP, ["hdfs", "dfs", "-du", "-s", SIZE_INPUT[s]["text"]])
        if du.returncode == 0 and du.stdout.strip():
            try:
                SIZE_INPUT[s]["bytes"] = int(du.stdout.split()[0])
            except Exception:
                pass


def streaming_jar_path() -> str:
    # Locate hadoop-streaming jar inside namenode container (3.2.x / 3.3.x layouts)
    r = docker_exec(
        CONTAINER_HADOOP,
        [
            "bash", "-lc",
            "ls /opt/hadoop*/share/hadoop/tools/lib/hadoop-streaming-*.jar "
            "/opt/hadoop/share/hadoop/tools/lib/hadoop-streaming-*.jar "
            "2>/dev/null | head -1",
        ],
    )
    path = (r.stdout or "").strip()
    if not path:
        raise RuntimeError("hadoop-streaming jar not found")
    return path


def run_mr_w1(input_path: str, output_path: str) -> subprocess.CompletedProcess:
    jar = streaming_jar_path()
    hdfs_rm(output_path)
    return docker_exec(
        CONTAINER_HADOOP,
        [
            "hadoop", "jar", jar,
            "-files", "/jobs/mapreduce/w1_mapper.py,/jobs/mapreduce/w1_reducer.py",
            "-mapper", "python3 w1_mapper.py",
            "-reducer", "python3 w1_reducer.py",
            "-input", input_path,
            "-output", output_path,
        ],
        timeout=6 * 3600,
    )


def run_mr_w2(input_path: str, output_path: str) -> subprocess.CompletedProcess:
    jar = streaming_jar_path()
    mid = output_path + "_wc"
    hdfs_rm(mid)
    hdfs_rm(output_path)
    r1 = docker_exec(
        CONTAINER_HADOOP,
        [
            "hadoop", "jar", jar,
            "-files", "/jobs/mapreduce/w1_mapper.py,/jobs/mapreduce/w1_reducer.py",
            "-mapper", "python3 w1_mapper.py",
            "-reducer", "python3 w1_reducer.py",
            "-input", input_path,
            "-output", mid,
        ],
        timeout=6 * 3600,
    )
    if r1.returncode != 0:
        return r1
    return docker_exec(
        CONTAINER_HADOOP,
        [
            "bash", "-lc",
            f"hadoop jar {jar} "
            f"-D mapreduce.job.reduces=1 "
            f"-files /jobs/mapreduce/w2_invert_mapper.py,/jobs/mapreduce/w2_topn_reducer.py "
            f"-mapper 'python3 w2_invert_mapper.py' "
            f"-reducer 'python3 w2_topn_reducer.py' "
            f"-input {mid} -output {output_path}",
        ],
        timeout=6 * 3600,
    )


def _read_n_nodes(size: str) -> int:
    meta = ROOT / "data" / "graph" / f"size_{size}.meta"
    if meta.exists():
        for line in meta.read_text(encoding="utf-8").splitlines():
            if line.startswith("nodes="):
                return int(line.split("=", 1)[1])
    defaults = {"S": 50_000, "M": 500_000, "L": 2_000_000}
    return defaults.get(size, 1)


def run_mr_w3(input_path: str, output_path: str, size: str, k: int = 5) -> subprocess.CompletedProcess:
    jar = streaming_jar_path()
    n_nodes = _read_n_nodes(size)
    join0 = output_path + "_join0"
    hdfs_rm(join0)
    hdfs_rm(output_path)
    # Build initial node\\trank\\tdests
    r0 = docker_exec(
        CONTAINER_HADOOP,
        [
            "bash", "-lc",
            f"export PR_N_NODES={n_nodes}; "
            f"hadoop jar {jar} "
            f"-files /jobs/mapreduce/w3_build_join_mapper.py,/jobs/mapreduce/w3_build_join_reducer.py "
            f"-mapper 'python3 w3_build_join_mapper.py' "
            f"-reducer 'python3 w3_build_join_reducer.py' "
            f"-input {input_path} -output {join0}",
        ],
        timeout=6 * 3600,
    )
    if r0.returncode != 0:
        return r0
    current = join0
    last = r0
    for i in range(k):
        nxt = f"{output_path}_iter{i}"
        hdfs_rm(nxt)
        last = docker_exec(
            CONTAINER_HADOOP,
            [
                "bash", "-lc",
                f"export PR_N_NODES={n_nodes}; export PR_DAMPING=0.85; "
                f"hadoop jar {jar} "
                f"-files /jobs/mapreduce/w3_contrib_mapper.py,/jobs/mapreduce/w3_contrib_reducer.py "
                f"-mapper 'python3 w3_contrib_mapper.py' "
                f"-reducer 'python3 w3_contrib_reducer.py' "
                f"-input {current} -output {nxt}",
            ],
            timeout=6 * 3600,
        )
        if last.returncode != 0:
            return last
        current = nxt
    # Copy final ranks only (node\\trank) to output
    last = docker_exec(
        CONTAINER_HADOOP,
        [
            "bash", "-lc",
            f"hdfs dfs -mkdir -p {output_path} && "
            f"hdfs dfs -cat {current}/part-* | awk -F'\\t' '{{print $1\"\\t\"$2}}' | "
            f"hdfs dfs -put - {output_path}/part-00000",
        ],
        timeout=3600,
    )
    return last


def spark_submit(script: str, extra: list[str], driver_mem: str, exec_mem: str) -> subprocess.CompletedProcess:
    # Use local[*] inside spark container for single-node parity
    cmd = [
        "spark-submit",
        "--master", "local[*]",
        "--driver-memory", driver_mem,
        "--conf", f"spark.executor.memory={exec_mem}",
        "--conf", "spark.hadoop.fs.defaultFS=hdfs://namenode:9000",
        script,
    ] + extra
    return docker_exec(CONTAINER_SPARK, cmd, timeout=6 * 3600)


def run_spark_w1(input_path: str, output_path: str, driver_mem: str, exec_mem: str):
    hdfs_rm(output_path)
    return spark_submit(
        "/jobs/spark/w1_wordcount.py",
        ["--input", input_path, "--output", output_path],
        driver_mem, exec_mem,
    )


def run_spark_w2(input_path: str, output_path: str, driver_mem: str, exec_mem: str):
    hdfs_rm(output_path)
    return spark_submit(
        "/jobs/spark/w2_topn.py",
        ["--input", input_path, "--output", output_path, "--n", "100"],
        driver_mem, exec_mem,
    )


def run_spark_w3(input_path: str, output_path: str, driver_mem: str, exec_mem: str):
    hdfs_rm(output_path)
    return spark_submit(
        "/jobs/spark/w3_pagerank.py",
        ["--input", input_path, "--output", output_path, "--iterations", "5"],
        driver_mem, exec_mem,
    )


def detect_oom(stderr: str, stdout: str) -> bool:
    text = (stderr or "") + "\n" + (stdout or "")
    keys = ["OutOfMemory", "OOM", "killed", "Cannot allocate", "Java heap space", "Container killed by YARN"]
    return any(k.lower() in text.lower() for k in keys)


def _parse_dotenv(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    if not path.is_file():
        return out
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        out[k.strip()] = v.strip().strip('"').strip("'")
    return out


def spark_mem_for_condition(condition: str) -> tuple[str, str]:
    """Driver/executor heap from .env.{condition}."""
    env = _parse_dotenv(ROOT / f".env.{condition}")
    defaults = {
        "high_ram": ("4g", "8g"),
        "low_ram": ("512m", "1024m"),
    }
    d_def, e_def = defaults.get(condition, ("2g", "4g"))
    import os
    driver = env.get("SPARK_DRIVER_MEMORY") or os.environ.get("SPARK_DRIVER_MEMORY") or d_def
    executor = env.get("SPARK_EXECUTOR_MEMORY") or os.environ.get("SPARK_EXECUTOR_MEMORY") or e_def
    print(f"spark mem from .env.{condition}: driver={driver} executor={executor}")
    return driver, executor


def one_trial(condition: str, engine: str, workload: str, size: str, trial: int) -> dict:
    out_base = f"/output/{condition}/{engine}/{workload}/{size}/trial{trial}"
    if workload in ("W1", "W2"):
        in_path = SIZE_INPUT[size]["text"]
        input_bytes = SIZE_INPUT[size]["bytes"]
    else:
        in_path = SIZE_INPUT[size]["graph"]
        # use graph du if possible
        input_bytes = SIZE_INPUT[size]["bytes"]
        du = docker_exec(CONTAINER_HADOOP, ["hdfs", "dfs", "-du", "-s", in_path])
        if du.returncode == 0 and du.stdout.strip():
            try:
                input_bytes = int(du.stdout.split()[0])
            except Exception:
                pass

    containers = [
        CONTAINER_HADOOP, "hs-datanode", "hs-resourcemanager",
        "hs-nodemanager", CONTAINER_SPARK,
    ]
    sampler = DockerStatsSampler(containers)
    notes = []
    ok = True
    driver_mem, exec_mem = spark_mem_for_condition(condition)

    sampler.start()
    t0 = time.time()
    try:
        if engine == "mapreduce":
            if workload == "W1":
                proc = run_mr_w1(in_path, out_base)
            elif workload == "W2":
                proc = run_mr_w2(in_path, out_base)
            else:
                proc = run_mr_w3(in_path, out_base, size)
        else:
            if workload == "W1":
                proc = run_spark_w1(in_path, out_base, driver_mem, exec_mem)
            elif workload == "W2":
                proc = run_spark_w2(in_path, out_base, driver_mem, exec_mem)
            else:
                proc = run_spark_w3(in_path, out_base, driver_mem, exec_mem)
        wall = time.time() - t0
        if proc.returncode != 0:
            ok = False
            notes.append(f"exit={proc.returncode}")
            if detect_oom(proc.stderr, proc.stdout):
                notes.append("OOM_or_killed")
            err_tail = (proc.stderr or proc.stdout or "")[-500:].replace("\n", " ")
            notes.append(err_tail)
        else:
            if detect_oom(proc.stderr, proc.stdout):
                notes.append("oom_warning_but_exit0")
    except subprocess.TimeoutExpired:
        wall = time.time() - t0
        ok = False
        notes.append("timeout")
    except Exception as e:
        wall = time.time() - t0
        ok = False
        notes.append(f"exception:{e}")
    finally:
        sampler.stop()

    thr = (input_bytes / (1024 * 1024) / wall) if wall > 0 else 0.0
    if sampler.error:
        notes.append(f"stats_err:{sampler.error}")

    row = {
        "condition": condition,
        "engine": engine,
        "workload": workload,
        "size": size,
        "trial": trial,
        "wall_sec": f"{wall:.3f}",
        "throughput_MBps": f"{thr:.4f}",
        "peak_mem_mb": f"{sampler.peak_mem_mb:.1f}",
        "peak_cpu_pct": f"{sampler.peak_cpu_pct:.1f}",
        "ok": "true" if ok else "false",
        "notes": "|".join(notes)[:800],
    }
    append_row(row)
    print("ROW", json.dumps(row))
    return row


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--condition", required=True, choices=["high_ram", "low_ram"])
    ap.add_argument("--workloads", default="W1", help="e.g. W1,W2,W3")
    ap.add_argument("--sizes", default="S", help="e.g. S,M,L")
    ap.add_argument("--engines", default="mapreduce,spark")
    ap.add_argument("--trials", type=int, default=1)
    ap.add_argument("--skip-upload", action="store_true")
    ap.add_argument(
        "--results",
        default=None,
        help="CSV path (default: results/results.csv). "
             "Use results/results_{condition}_{workload}.csv to split by env+workload.",
    )
    args = ap.parse_args()

    global RESULTS
    if args.results:
        RESULTS = Path(args.results)
        if not RESULTS.is_absolute():
            RESULTS = ROOT / RESULTS

    workloads = [w.strip().upper() for w in args.workloads.split(",") if w.strip()]
    sizes = [s.strip().upper() for s in args.sizes.split(",") if s.strip()]
    engines = [e.strip().lower() for e in args.engines.split(",") if e.strip()]

    ensure_csv()
    if not args.skip_upload:
        print("Uploading datasets to HDFS (if needed)...")
        upload_datasets(sizes)

    for wl in workloads:
        for size in sizes:
            for engine in engines:
                for trial in range(1, args.trials + 1):
                    print(f"=== {args.condition} {engine} {wl} {size} trial={trial} ===")
                    one_trial(args.condition, engine, wl, size, trial)

    print(f"Done. Results -> {RESULTS}")


if __name__ == "__main__":
    main()
