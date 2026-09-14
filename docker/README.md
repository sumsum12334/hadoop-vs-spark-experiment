# Docker notes

- Images: `sbloodys/hadoop:3.3.6` (linux/amd64 + linux/arm64) + `bitnamilegacy/spark:3.5.5`
- Why not `bde2020/hadoop-*`? Those tags are amd64-only and crash with `exec format error` on ARM Docker Desktop.
- HDFS defaultFS: `hdfs://namenode:9000`
- Memory caps come from `.env.high_ram` / `.env.low_ram` via `MEM_LIMIT` / YARN / Spark env vars
- UIs: NameNode http://localhost:9870 , YARN http://localhost:8088 , Spark http://localhost:8080
