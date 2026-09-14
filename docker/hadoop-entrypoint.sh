#!/bin/bash
# sbloodys/hadoop starter.sh always does `sudo chmod o+rwx /data`.
# That fails when /data is a read-only (or otherwise unchmodable) mount.
# Bypass by exec'ing the requested Hadoop command directly.
set -euo pipefail
exec "$@"
