#!/usr/bin/env python3
"""PageRank-lite contrib mapper.
Reads mixed lines:
  EDGE\\tsrc\\tdst
  RANK\\tnode\\trank
Emits for each node: adjacency + rank; then contribs to neighbors.
Actually runner feeds a joined format: node\\trank\\tdest1,dest2,...
"""
import sys

DAMPING = 0.85

def main():
    for line in sys.stdin:
        line = line.rstrip("\n")
        if not line:
            continue
        parts = line.split("\t")
        # node \\t rank \\t dests (comma-separated, may be empty)
        if len(parts) < 2:
            continue
        node = parts[0]
        try:
            rank = float(parts[1])
        except ValueError:
            continue
        dests = parts[2].split(",") if len(parts) > 2 and parts[2] else []
        dests = [d for d in dests if d]
        # Keep graph structure for next join (pass-through via side channel is hard
        # in pure streaming). Emit STRUCTURE and CONTRIB.
        sys.stdout.write(f"{node}\tSTRUCTURE\t{','.join(dests)}\n")
        if not dests:
            # dangling: emit to special sink handled by reducer mass (simplified: self)
            sys.stdout.write(f"{node}\tCONTRIB\t{rank}\n")
        else:
            share = rank / len(dests)
            for d in dests:
                sys.stdout.write(f"{d}\tCONTRIB\t{share}\n")

if __name__ == "__main__":
    main()
