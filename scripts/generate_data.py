#!/usr/bin/env python3
"""Generate synthetic datasets for W1/W2 (text) and W3 (graph).

Sizes (approximate on-disk):
  S ~ 100 MB
  M ~ 1 GB
  L ~ 5 GB

Usage:
  python scripts/generate_data.py --sizes S,M,L
  python scripts/generate_data.py --sizes S --force
"""
from __future__ import annotations

import argparse
import os
import random
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"

# Target bytes (approximate)
SIZE_BYTES = {
    "S": 100 * 1024 * 1024,
    "M": 1 * 1024 * 1024 * 1024,
    "L": 5 * 1024 * 1024 * 1024,
}

# Graph edge counts chosen so edge-list text ≈ size target
# ~24 bytes/edge average -> scale edges
GRAPH_EDGES = {
    "S": 4_000_000,    # ~100MB
    "M": 40_000_000,   # ~1GB
    "L": 200_000_000,  # ~5GB
}
GRAPH_NODES = {
    "S": 50_000,
    "M": 500_000,
    "L": 2_000_000,
}

VOCAB = [
    "alpha", "beta", "gamma", "delta", "epsilon", "zeta", "eta", "theta",
    "data", "spark", "hadoop", "mapreduce", "cluster", "memory", "disk",
    "shuffle", "cache", "iterator", "batch", "latency", "throughput",
    "node", "edge", "graph", "rank", "count", "word", "token", "stream",
    "yarn", "hdfs", "block", "replica", "executor", "driver", "worker",
]


def ensure_dirs():
    (DATA / "text").mkdir(parents=True, exist_ok=True)
    (DATA / "graph").mkdir(parents=True, exist_ok=True)


def generate_text(label: str, target: int, force: bool = False) -> Path:
    out = DATA / "text" / f"size_{label}.txt"
    if out.exists() and out.stat().st_size >= target * 0.95 and not force:
        print(f"[skip] {out} already ~{out.stat().st_size} bytes")
        return out
    print(f"[gen] text {label} -> {out} target={target}")
    rng = random.Random(1000 + ord(label[0]))
    # Prebuild lines for speed
    lines = []
    for _ in range(2000):
        n = rng.randint(8, 40)
        words = [VOCAB[rng.randrange(len(VOCAB))] for _ in range(n)]
        # sprinkle rare tokens for Zipf-ish top-N interest
        if rng.random() < 0.05:
            words.append(f"rare{rng.randint(1, 500)}")
        lines.append(" ".join(words) + "\n")
    blob = "".join(lines).encode("utf-8")
    with open(out, "wb") as f:
        written = 0
        while written < target:
            chunk = blob if written + len(blob) <= target else blob[: target - written]
            f.write(chunk)
            written += len(chunk)
            if written & ((32 << 20) - 1) == 0:
                print(f"  ... {written / (1024*1024):.1f} MB")
    print(f"[done] {out} ({out.stat().st_size} bytes)")
    return out


def generate_graph(label: str, force: bool = False) -> Path:
    out = DATA / "graph" / f"size_{label}.edges"
    n_edges = GRAPH_EDGES[label]
    n_nodes = GRAPH_NODES[label]
    # Rough size check
    approx = n_edges * 20
    if out.exists() and out.stat().st_size >= approx * 0.8 and not force:
        print(f"[skip] {out} already ~{out.stat().st_size} bytes")
        return out
    print(f"[gen] graph {label} -> {out} nodes={n_nodes} edges={n_edges}")
    rng = random.Random(2000 + ord(label[0]))
    with open(out, "w", encoding="utf-8", buffering=1024 * 1024) as f:
        f.write(f"# pagerank-lite edges nodes~{n_nodes} edges={n_edges}\n")
        for i in range(n_edges):
            src = rng.randrange(n_nodes)
            dst = rng.randrange(n_nodes)
            if dst == src:
                dst = (dst + 1) % n_nodes
            f.write(f"{src} {dst}\n")
            if i and i % 5_000_000 == 0:
                print(f"  ... {i} edges")
    print(f"[done] {out} ({out.stat().st_size} bytes)")
    # Sidecar with node count for MR env
    meta = DATA / "graph" / f"size_{label}.meta"
    meta.write_text(f"nodes={n_nodes}\nedges={n_edges}\n", encoding="utf-8")
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sizes", default="S", help="Comma list: S,M,L")
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--text-only", action="store_true")
    ap.add_argument("--graph-only", action="store_true")
    args = ap.parse_args()
    ensure_dirs()
    sizes = [s.strip().upper() for s in args.sizes.split(",") if s.strip()]
    for s in sizes:
        if s not in SIZE_BYTES:
            raise SystemExit(f"Unknown size {s}")
        if not args.graph_only:
            generate_text(s, SIZE_BYTES[s], force=args.force)
        if not args.text_only:
            generate_graph(s, force=args.force)
    print("All requested datasets ready under data/")


if __name__ == "__main__":
    main()
