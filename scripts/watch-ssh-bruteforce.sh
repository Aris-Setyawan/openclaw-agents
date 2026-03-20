#!/bin/sh
set -eu
LOG_FILE="/var/log/auth.log"
PATTERN='Failed password|Invalid user|authentication failure|Connection closed by invalid user'

touch "$LOG_FILE"

echo "Watching $LOG_FILE for new SSH brute-force entries..." >&2
# -F follows across rotation; awk exits on first matching line.
tail -Fn0 "$LOG_FILE" | awk '/Failed password|Invalid user|authentication failure|Connection closed by invalid user/ { print; exit 0 }'
