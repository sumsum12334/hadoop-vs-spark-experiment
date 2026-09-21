#!/usr/bin/env python3
"""Plot experiment results (RQ1–RQ3 style charts).

Requires: pandas, matplotlib (install via pip if missing).
Does nothing harmful if results.csv has only a header / few rows.
"""
from __future__ import annotations

import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CSV = ROOT / "results" / "results.csv"
FIG = ROOT / "results" / "figures"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--csv", default=str(CSV))
    args = ap.parse_args()
    FIG.mkdir(parents=True, exist_ok=True)

    try:
        import pandas as pd
        import matplotlib.pyplot as plt
        import numpy as np
    except ImportError:
        print("Install plotting deps: pip install pandas matplotlib")
        raise SystemExit(1)

    df = pd.read_csv(args.csv)
    if df.empty or "wall_sec" not in df.columns:
        print("No data rows yet — skipping plots.")
        return

    df = df[df["ok"].astype(str).str.lower().isin(["true", "1", "yes"])].copy()
    if df.empty:
        print("No successful rows — skipping plots.")
        return

    df["wall_sec"] = pd.to_numeric(df["wall_sec"], errors="coerce")
    df["peak_mem_mb"] = pd.to_numeric(df["peak_mem_mb"], errors="coerce")

    # RQ1: fixed size M (or first available), bar by workload × engine × condition
    for size in ["M", "L", "S"]:
        sub = df[df["size"] == size]
        if sub.empty:
            continue
        g = sub.groupby(["condition", "workload", "engine"])["wall_sec"].agg(["mean", "std", "count"])
        # grouped bar per condition
        for cond in sub["condition"].unique():
            csub = sub[sub["condition"] == cond]
            pivot = csub.groupby(["workload", "engine"])["wall_sec"].mean().unstack("engine")
            err = csub.groupby(["workload", "engine"])["wall_sec"].std().unstack("engine")
            ax = pivot.plot(kind="bar", yerr=err, capsize=3, figsize=(8, 5))
            ax.set_ylabel("wall_sec (mean ± std)")
            ax.set_title(f"RQ1-ish: wall time by workload ({cond}, size={size})")
            ax.legend(title="engine")
            plt.tight_layout()
            out = FIG / f"rq1_wall_{cond}_{size}.png"
            plt.savefig(out, dpi=140)
            plt.close()
            print("wrote", out)

    # RQ2: time vs size lines per workload/engine/condition
    for cond in df["condition"].unique():
        for wl in df["workload"].unique():
            csub = df[(df["condition"] == cond) & (df["workload"] == wl)]
            if csub.empty:
                continue
            fig, ax = plt.subplots(figsize=(7, 4))
            for engine, esub in csub.groupby("engine"):
                stats = esub.groupby("size")["wall_sec"].agg(["mean", "std"])
                # order S,M,L
                order = [s for s in ["S", "M", "L"] if s in stats.index]
                stats = stats.loc[order]
                ax.errorbar(order, stats["mean"], yerr=stats["std"], marker="o", label=engine, capsize=3)
            ax.set_xlabel("size")
            ax.set_ylabel("wall_sec")
            ax.set_title(f"RQ2: scalability {wl} ({cond})")
            ax.legend()
            plt.tight_layout()
            out = FIG / f"rq2_scale_{cond}_{wl}.png"
            plt.savefig(out, dpi=140)
            plt.close()
            print("wrote", out)

    # RQ3: peak memory
    for size in df["size"].unique():
        sub = df[df["size"] == size]
        pivot = sub.groupby(["condition", "workload", "engine"])["peak_mem_mb"].mean().unstack("engine")
        if pivot.empty:
            continue
        ax = pivot.plot(kind="bar", figsize=(9, 5))
        ax.set_ylabel("peak_mem_mb (mean)")
        ax.set_title(f"RQ3: peak memory (size={size})")
        plt.tight_layout()
        out = FIG / f"rq3_mem_{size}.png"
        plt.savefig(out, dpi=140)
        plt.close()
        print("wrote", out)

    print("Plots under", FIG)


if __name__ == "__main__":
    main()
