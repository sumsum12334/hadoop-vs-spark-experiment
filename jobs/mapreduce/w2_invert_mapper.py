#!/usr/bin/env python3
"""W2 stage-2 mapper: word\\tcount -> zero-padded count\\tword (for desc sort)"""
import sys

def main():
    for line in sys.stdin:
        line = line.rstrip("\n")
        if not line:
            continue
        parts = line.split("\t")
        if len(parts) < 2:
            continue
        word, count_s = parts[0], parts[1]
        try:
            c = int(count_s)
        except ValueError:
            continue
        # Descending numeric sort via (MAX - c) zero-pad key
        key = f"{(2**31 - 1) - c:010d}"
        sys.stdout.write(f"{key}\t{c}\t{word}\n")

if __name__ == "__main__":
    main()
