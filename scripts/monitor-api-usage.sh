#!/bin/bash
# Monitor API usage untuk detect loops/anomali
# Log setiap image/video generation ke file tracking

LOG_FILE="/root/.openclaw/workspace/logs/api-usage.log"
mkdir -p "$(dirname "$LOG_FILE")"

# Deteksi jenis request dari command line atau caller
CALLER="${1:-unknown}"
TYPE="${2:-unknown}"  # image|video
PROVIDER="${3:-unknown}"  # gemini|kieai|openai

TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
echo "$TIMESTAMP | $CALLER | $TYPE | $PROVIDER" >> "$LOG_FILE"

# Check for suspicious patterns (>5 requests in 1 minute)
RECENT_COUNT=$(tail -100 "$LOG_FILE" | grep "$(date -u +"%Y-%m-%d %H:%M")" | wc -l)

if [ "$RECENT_COUNT" -gt 5 ]; then
  echo "[WARNING] Suspicious API usage: $RECENT_COUNT requests in last minute" >&2
  echo "$(date -u +"%Y-%m-%d %H:%M:%S UTC") | ALERT | Rate spike detected: $RECENT_COUNT req/min" >> "$LOG_FILE"
fi

# Auto-cleanup old logs (keep last 30 days)
find "$(dirname "$LOG_FILE")" -name "api-usage.log.*" -mtime +30 -delete 2>/dev/null

# Rotate jika >1MB
if [ -f "$LOG_FILE" ] && [ "$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE")" -gt 1048576 ]; then
  mv "$LOG_FILE" "$LOG_FILE.$(date +%Y%m%d-%H%M%S)"
fi

exit 0
