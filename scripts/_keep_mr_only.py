from pathlib import Path
import csv, sys
p = Path(sys.argv[1])
if not p.exists():
    print("missing", p); raise SystemExit(0)
rows = list(csv.DictReader(p.open(encoding="utf-8")))
hdr = list(rows[0].keys()) if rows else None
if not hdr:
    # empty-ish file with header only
    text = p.read_text(encoding="utf-8")
    print("no data rows", p); raise SystemExit(0)
kept = [r for r in rows if (r.get("engine") or "").lower() != "spark"]
dropped = len(rows) - len(kept)
with p.open("w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=hdr)
    w.writeheader()
    w.writerows(kept)
print(f"{p.name}: kept={len(kept)} dropped_spark={dropped}")
