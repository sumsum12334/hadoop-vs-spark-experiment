#!/usr/bin/env python3
"""Build initial join rows from edges: emit node\\t1.0\\tdest for adjacency list build.
Input edges: src\\tdst
Output for reducer: src\\tDEST\\tdst  and also ensure dst appears as node.
"""
import sys

def main():
    for line in sys.stdin:
        line = line.rstrip("\n")
        if not line or line.startswith("#"):
            continue
        parts = line.split()
        if len(parts) < 2:
            continue
        src, dst = parts[0], parts[1]
        sys.stdout.write(f"{src}\tDEST\t{dst}\n")
        sys.stdout.write(f"{dst}\tNODE\t1\n")
        sys.stdout.write(f"{src}\tNODE\t1\n")

if __name__ == "__main__":
    main()
