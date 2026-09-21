#!/usr/bin/env bash
# Usage: ./scripts/compose_up.sh high_ram|low_ram
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROFILE="${1:-high_ram}"
ENV_FILE="$ROOT/.env.$PROFILE"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE" >&2
  exit 1
fi
cd "$ROOT"
docker compose --env-file "$ENV_FILE" up -d
"$ROOT/scripts/wait_hdfs.sh"
"$ROOT/scripts/ensure_python_in_hadoop.sh"
echo "Compose up with $PROFILE"
