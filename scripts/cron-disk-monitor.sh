#!/bin/bash
# Zero-token disk monitor untuk cron langsung (tidak via OpenClaw agent)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZERO_TOKEN_SCRIPT="$SCRIPT_DIR/zero-token-monitor.py"
LOG_FILE="/root/.openclaw/workspace/logs/cron-disk.log"

# Buat log directory jika belum ada
mkdir -p "$(dirname "$LOG_FILE")"

# Timestamp
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

echo "[$TIMESTAMP] Starting zero-token disk monitor..." >> "$LOG_FILE"

# Jalankan Python script
cd "$SCRIPT_DIR"
python3 zero-token-monitor.py disk 2>&1 | tee -a "$LOG_FILE"

EXIT_CODE=${PIPESTATUS[0]}

echo "[$TIMESTAMP] Exit code: $EXIT_CODE" >> "$LOG_FILE"

# Jika ada alert (exit code 1), script sudah kirim Telegram sendiri
# Jika tidak ada alert (exit code 0), tidak perlu action

exit $EXIT_CODE