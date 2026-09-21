#!/usr/bin/env python3
"""Aggregate adjacency; init rank=1/N. Needs PR_N_NODES env (approx ok if set by runner)."""
import os
import sys

N_NODES = float(os.environ.get("PR_N_NODES", "1"))

def main():
    current = None
    dests = []

    def flush(node, dests):
        if node is None:
            return
        rank = 1.0 / max(N_NODES, 1.0)
        sys.stdout.write(f"{node}\t{rank:.10f}\t{','.join(sorted(set(dests)))}\n")

    for line in sys.stdin:
        line = line.rstrip("\n")
        parts = line.split("\t")
        if len(parts) < 3:
            continue
        node, kind, payload = parts[0], parts[1], parts[2]
        if current is None:
            current = node
        if node != current:
            flush(current, dests)
            current = node
            dests = []
        if kind == "DEST":
            dests.append(payload)
    flush(current, dests)

if __name__ == "__main__":
    main()
