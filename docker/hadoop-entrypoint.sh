#!/bin/bash
# Apply YARN-SITE.XML_* env via image envtoconf, skip failing chmod /data, then exec.
set -eu
sudo chmod o+rwx /data 2>/dev/null || true
python3 /opt/envtoconf.py --destination "${HADOOP_CONF_DIR:-/opt/hadoop/etc/hadoop}"
exec "$@"