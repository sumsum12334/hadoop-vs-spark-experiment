#!/usr/bin/env bash
set -euo pipefail
for c in hs-namenode hs-nodemanager; do
  if docker exec "$c" bash -lc 'command -v python3' >/dev/null 2>&1; then
    echo "$c: python3 OK ($(docker exec "$c" python3 --version 2>&1))"
  else
    echo "$c: installing python3..."
    docker exec -u root "$c" bash -lc '
set -e
if command -v apt-get >/dev/null 2>&1; then
  apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq python3
elif command -v microdnf >/dev/null 2>&1; then
  microdnf install -y python3
elif command -v yum >/dev/null 2>&1; then
  yum install -y python3
else
  echo "No known package manager" >&2; exit 1
fi
'
    docker exec "$c" python3 --version
  fi
done
