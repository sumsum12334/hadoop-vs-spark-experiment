from pathlib import Path
path = Path(r"C:\git\ust\hadoop-vs-spark-experiment\scripts\run_experiment.py")
text = path.read_text(encoding="utf-8")
old = "def spark_mem_for_condition(condition: str) -> tuple[str, str]:\n    if condition == \"low_ram\":\n        return \"512m\", \"1024m\"\n    return \"2g\", \"4g\"\n"
new = '''def _parse_dotenv(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    if not path.is_file():
        return out
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        out[k.strip()] = v.strip().strip('"').strip("'")
    return out


def spark_mem_for_condition(condition: str) -> tuple[str, str]:
    """Driver/executor heap from .env.{condition}."""
    env = _parse_dotenv(ROOT / f".env.{condition}")
    defaults = {
        "high_ram": ("4g", "8g"),
        "low_ram": ("512m", "1024m"),
    }
    d_def, e_def = defaults.get(condition, ("2g", "4g"))
    import os
    driver = env.get("SPARK_DRIVER_MEMORY") or os.environ.get("SPARK_DRIVER_MEMORY") or d_def
    executor = env.get("SPARK_EXECUTOR_MEMORY") or os.environ.get("SPARK_EXECUTOR_MEMORY") or e_def
    print(f"spark mem from .env.{condition}: driver={driver} executor={executor}")
    return driver, executor
'''
# normalize to file newlines
if "\r\n" in text:
    old = old.replace("\n", "\r\n")
    new = new.replace("\n", "\r\n")
if old not in text:
    raise SystemExit("OLD BLOCK MISSING")
path.write_text(text.replace(old, new), encoding="utf-8")
print("OK")
