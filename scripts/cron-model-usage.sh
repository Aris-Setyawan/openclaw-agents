#!/bin/bash
# Zero-token model usage monitor untuk cron langsung

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZERO_TOKEN_SCRIPT="$SCRIPT_DIR/zero-token-monitor.py"
LOG_FILE="/root/.openclaw/workspace/logs/cron-model-usage.log"

mkdir -p "$(dirname "$LOG_FILE")"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$TIMESTAMP] Starting zero-token model usage monitor..." >> "$LOG_FILE"

cd "$SCRIPT_DIR"
python3 zero-token-monitor.py model 2>&1 | tee -a "$LOG_FILE"

EXIT_CODE=${PIPESTATUS[0]}
echo "[$TIMESTAMP] Exit code: $EXIT_CODE" >> "$LOG_FILE"

exit $EXIT_CODE