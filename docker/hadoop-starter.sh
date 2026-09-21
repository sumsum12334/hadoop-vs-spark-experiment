#!/bin/bash
set -eu
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Ignore chmod failures on bind mounts
sudo chmod o+rwx /data 2>/dev/null || true
if [ -f "$DIR/envtoconf.py" ]; then
  python3 "$DIR/envtoconf.py" --destination "${HADOOP_CONF_DIR:-/opt/hadoop/etc/hadoop}"
elif [ -f /opt/starter/envtoconf.py ]; then
  python3 /opt/starter/envtoconf.py --destination "${HADOOP_CONF_DIR:-/opt/hadoop/etc/hadoop}"
fi
exec "$@"