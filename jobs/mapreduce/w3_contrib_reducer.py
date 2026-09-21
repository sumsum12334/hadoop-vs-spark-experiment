#!/usr/bin/env python3
"""PageRank-lite reducer: new_rank = (1-d)/N + d * sum(contribs); re-emit node\\trank\\tdests"""
import os
import sys

DAMPING = float(os.environ.get("PR_DAMPING", "0.85"))
N_NODES = float(os.environ.get("PR_N_NODES", "1"))

def main():
    current = None
    structure = ""
    contrib_sum = 0.0

    def flush(node, structure, contrib_sum):
        if node is None:
            return
        base = (1.0 - DAMPING) / max(N_NODES, 1.0)
        new_rank = base + DAMPING * contrib_sum
        sys.stdout.write(f"{node}\t{new_rank:.10f}\t{structure}\n")

    for line in sys.stdin:
        line = line.rstrip("\n")
        parts = line.split("\t")
        if len(parts) < 3:
            continue
        node, kind, payload = parts[0], parts[1], parts[2]
        if current is None:
            current = node
        if node != current:
            flush(current, structure, contrib_sum)
            current = node
            structure = ""
            contrib_sum = 0.0
        if kind == "STRUCTURE":
            structure = payload
        elif kind == "CONTRIB":
            try:
                contrib_sum += float(payload)
            except ValueError:
                pass
    flush(current, structure, contrib_sum)

if __name__ == "__main__":
    main()
