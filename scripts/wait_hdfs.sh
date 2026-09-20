#!/usr/bin/env bash
set -euo pipefail
echo "Waiting for HDFS namenode..."
for i in $(seq 1 60); do
  if docker exec hs-namenode hdfs dfs -ls / >/dev/null 2>&1; then
    echo "HDFS is up."
    exit 0
  fi
  sleep 5
done
echo "HDFS did not become ready in time" >&2
exit 1
