#!/bin/bash
# log-model-fallback.sh - Log model fallback events
# Usage: log-model-fallback.sh <agent> <primary_model> <fallback_model> <reason>
#
# Example:
#   log-model-fallback.sh agent1 "gemini-2.5-flash" "openrouter/gemini" "rate_limit"

AGENT="$1"
PRIMARY="$2"
FALLBACK="$3"
REASON="${4:-unknown}"

if [ -z "$AGENT" ] || [ -z "$PRIMARY" ] || [ -z "$FALLBACK" ]; then
  echo "Usage: log-model-fallback.sh <agent> <primary_model> <fallback_model> [reason]" >&2
  exit 1
fi

FALLBACK_LOG="/root/.openclaw/workspace/logs/model-fallback.log"
TELEGRAM_SEND="/root/.openclaw/workspace/scripts/telegram-send.sh"

mkdir -p "$(dirname "$FALLBACK_LOG")"

TIMESTAMP=$(date -u '+%Y-%m-%d %H:%M:%S UTC')

# Log entry
LOG_ENTRY="[$TIMESTAMP] $AGENT: $PRIMARY → $FALLBACK (reason: $REASON)"
echo "$LOG_ENTRY" >> "$FALLBACK_LOG"

# Send Telegram notification
"$TELEGRAM_SEND" "" "⚠️ **MODEL FALLBACK DETECTED**

**Agent:** $AGENT
**Primary:** $PRIMARY (FAILED)
**Fallback:** $FALLBACK (ACTIVE)
**Reason:** $REASON

**Time:** $TIMESTAMP

**Impact:**
- Cost may increase (fallback often more expensive)
- Check primary model status
- Review logs: \`tail /root/.openclaw/workspace/logs/model-fallback.log\`

**Action:**
- If temporary: Primary will auto-recover
- If persistent: Check API key, rate limits, quota" 2>/dev/null || true

echo "$LOG_ENTRY"
exit 0
