#!/usr/bin/env python3
"""W1 WordCount reducer — sum counts per word"""
import sys

def main():
    current = None
    total = 0
    for line in sys.stdin:
        line = line.rstrip("\n")
        if not line:
            continue
        parts = line.split("\t")
        if len(parts) < 2:
            continue
        word, val = parts[0], parts[1]
        try:
            n = int(val)
        except ValueError:
            continue
        if current is None:
            current = word
            total = n
        elif word == current:
            total += n
        else:
            sys.stdout.write(f"{current}\t{total}\n")
            current = word
            total = n
    if current is not None:
        sys.stdout.write(f"{current}\t{total}\n")

if __name__ == "__main__":
    main()
