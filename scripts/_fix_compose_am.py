from pathlib import Path
root = Path(r"C:\git\ust\hadoop-vs-spark-experiment")
compose = root / "docker-compose.yml"
text = compose.read_text(encoding="utf-8")
old = 'MAPRED-SITE.XML_yarn.app.mapreduce.am.resource.mb: ${YARN_AM_MEMORY_MB:-256}'
new = 'MAPRED-SITE.XML_yarn.app.mapreduce.am.resource.mb: "${YARN_AM_MEMORY_MB:-256}"'
if old in text:
    text = text.replace(old, new)
    compose.write_text(text, encoding="utf-8", newline="\n")
    print("quoted AM resource")
else:
    print("AM line not found exact; current:")
    for line in text.splitlines():
        if "am.resource" in line or "am.command" in line:
            print(repr(line))

# Find any weird unicode in compose
for n, line in enumerate(text.splitlines(), 1):
    for j, ch in enumerate(line):
        o = ord(ch)
        if o > 127:
            print(f"nonascii line {n} col {j} U+{o:04X} {ch!r}")

low = """# Low-RAM profile (~2GB) - same CPU; only memory caps change
COMPOSE_PROJECT_NAME=hscompare
RAM_PROFILE=low_ram
MEM_LIMIT=2g
CPU_LIMIT=4.0
HADOOP_HEAPSIZE=384
YARN_NODEMANAGER_MEMORY_MB=1536
YARN_SCHEDULER_MAX_MB=1536
SPARK_WORKER_MEMORY=1536m
SPARK_DRIVER_MEMORY=512m
SPARK_EXECUTOR_MEMORY=1024m
YARN_AM_MEMORY_MB=256
YARN_AM_XMX=200m
"""
high = """# High-RAM profile (~16GB) - fair cap applied to BOTH engines containers
COMPOSE_PROJECT_NAME=hscompare
RAM_PROFILE=high_ram
MEM_LIMIT=16g
CPU_LIMIT=4.0
HADOOP_HEAPSIZE=2048
YARN_NODEMANAGER_MEMORY_MB=12288
YARN_SCHEDULER_MAX_MB=12288
SPARK_WORKER_MEMORY=12g
SPARK_DRIVER_MEMORY=4g
SPARK_EXECUTOR_MEMORY=8g
YARN_AM_MEMORY_MB=1024
YARN_AM_XMX=768m
"""
(root / ".env.low_ram").write_text(low, encoding="utf-8", newline="\n")
(root / ".env.high_ram").write_text(high, encoding="utf-8", newline="\n")
print("env ok")
