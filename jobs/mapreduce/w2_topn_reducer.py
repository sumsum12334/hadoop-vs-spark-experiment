#!/usr/bin/env python3
"""W2 stage-2 reducer: emit top N=100 (word, count). Use -D mapreduce.job.reduces=1"""
import os
import sys

N = int(os.environ.get("TOP_N", "100"))

def main():
    emitted = 0
    for line in sys.stdin:
        if emitted >= N:
            break
        line = line.rstrip("\n")
        parts = line.split("\t")
        if len(parts) < 3:
            continue
        _key, count_s, word = parts[0], parts[1], parts[2]
        sys.stdout.write(f"{word}\t{count_s}\n")
        emitted += 1

if __name__ == "__main__":
    main()
