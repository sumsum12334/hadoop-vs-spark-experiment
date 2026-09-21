#!/usr/bin/env python3
"""Merge results/results_<condition>_<workload>.csv into results/results_all.csv."""
from pathlib import Path
import csv

ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / "results"

def main():
    files = sorted(RES.glob("results_*_W*.csv"))
    out = RES / "results_all.csv"
    header = None
    rows = []
    for f in files:
        with f.open(newline="", encoding="utf-8") as fh:
            r = csv.DictReader(fh)
            if header is None:
                header = r.fieldnames
            rows.extend(r)
    if header is None:
        print("No per-env/workload CSVs found.")
        return
    with out.open("w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=header)
        w.writeheader()
        w.writerows(rows)
    print(f"Merged {len(files)} files -> {out} ({len(rows)} rows)")

if __name__ == "__main__":
    main()
