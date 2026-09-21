#!/usr/bin/env python3
"""W1 WordCount mapper — emit word\\t1"""
import re
import sys

WORD = re.compile(r"[^a-z0-9]+")

def tokens(line: str):
    for t in WORD.split(line.lower()):
        if t:
            yield t

def main():
    for line in sys.stdin:
        for w in tokens(line):
            sys.stdout.write(f"{w}\t1\n")

if __name__ == "__main__":
    main()
