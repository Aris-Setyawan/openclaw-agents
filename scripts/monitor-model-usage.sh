#!/bin/bash
# monitor-model-usage.sh - Monitor API usage & detect spikes/fallbacks
# Usage: monitor-model-usage.sh
# Run periodically (e.g., every hour via cron or heartbeat)

STATE_FILE="/root/.openclaw/workspace/logs/model-usage-state.json"
ALERT_LOG="/root/.openclaw/workspace/logs/model-alerts.log"
TELEGRAM_SEND="/root/.openclaw/workspace/scripts/telegram-send.sh"

mkdir -p "$(dirname "$STATE_FILE")"
mkdir -p "$(dirname "$ALERT_LOG")"

# Initialize state file if not exists
if [ ! -f "$STATE_FILE" ]; then
  echo '{"last_check_ts": 0, "providers": {}}' > "$STATE_FILE"
fi

TIMESTAMP=$(date +%s)
DATETIME=$(date -u '+%Y-%m-%d %H:%M UTC')

# ━━━ Read keys from auth-profiles ━━━
AUTH_FILE="/root/.openclaw/agents/agent1/agent/auth-profiles.json"
DS_KEY=$(python3 -c "import json; d=json.load(open('$AUTH_FILE')); print(d['profiles']['deepseek:default']['token'])" 2>/dev/null)
OR_KEY=$(python3 -c "import json; d=json.load(open('$AUTH_FILE')); print(d['profiles']['openrouter:default']['key'])" 2>/dev/null)

# ━━━ Fetch current balances ━━━

# DeepSeek
DEEPSEEK_BALANCE=$(curl -s https://api.deepseek.com/user/balance \
  -H "Authorization: Bearer $DS_KEY" | \
  jq -r '.balance_infos[0].total_balance // "0"' 2>/dev/null || echo "0")

# OpenRouter
OPENROUTER_USAGE=$(curl -s https://openrouter.ai/api/v1/auth/key \
  -H "Authorization: Bearer $OR_KEY" | \
  jq -r '.data.usage // 0' 2>/dev/null || echo "0")

# Load previous state
PREV_STATE=$(cat "$STATE_FILE")
PREV_DEEPSEEK=$(echo "$PREV_STATE" | jq -r '.providers.deepseek.balance // 0')
PREV_OPENROUTER=$(echo "$PREV_STATE" | jq -r '.providers.openrouter.usage // 0')
LAST_CHECK=$(echo "$PREV_STATE" | jq -r '.last_check_ts // 0')

# Calculate changes
DEEPSEEK_USED=$(echo "$PREV_DEEPSEEK - $DEEPSEEK_BALANCE" | bc -l 2>/dev/null || echo "0")
OPENROUTER_INCREASE=$(echo "$OPENROUTER_USAGE - $PREV_OPENROUTER" | bc -l 2>/dev/null || echo "0")

TIME_ELAPSED=$((TIMESTAMP - LAST_CHECK))
HOURS_ELAPSED=$(echo "scale=2; $TIME_ELAPSED / 3600" | bc -l 2>/dev/null || echo "1")

# ━━━ Spike Detection ━━━

send_alert() {
  local MESSAGE="$1"
  echo "[$DATETIME] ALERT: $MESSAGE" >> "$ALERT_LOG"
  "$TELEGRAM_SEND" "" "🚨 API USAGE ALERT

$MESSAGE

Time: $DATETIME
Check logs for details." 2>/dev/null || true
}

# DeepSeek spike detection
if [ "$HOURS_ELAPSED" != "0" ]; then
  DEEPSEEK_HOURLY=$(echo "scale=4; $DEEPSEEK_USED / $HOURS_ELAPSED" | bc -l 2>/dev/null || echo "0")
  DEEPSEEK_THRESHOLD="0.10"  # $0.10/hour threshold
  
  if [ "$(echo "$DEEPSEEK_HOURLY > $DEEPSEEK_THRESHOLD" | bc -l)" -eq 1 ]; then
    DAILY_PROJ=$(echo "scale=2; $DEEPSEEK_HOURLY * 24" | bc -l)
    MONTHLY_PROJ=$(echo "scale=2; $DEEPSEEK_HOURLY * 24 * 30" | bc -l)
    send_alert "DeepSeek USAGE SPIKE!

Used: \$$DEEPSEEK_USED in ${HOURS_ELAPSED}h
Rate: ~\$$DEEPSEEK_HOURLY/hour

Projected:
- Daily: ~\$$DAILY_PROJ/day
- Monthly: ~\$$MONTHLY_PROJ/month

Current balance: \$$DEEPSEEK_BALANCE

⚠️  Check for context bloat or excessive calls!"
  fi
fi

# OpenRouter spike detection
if [ "$HOURS_ELAPSED" != "0" ]; then
  OPENROUTER_HOURLY=$(echo "scale=4; $OPENROUTER_INCREASE / $HOURS_ELAPSED" | bc -l 2>/dev/null || echo "0")
  OPENROUTER_THRESHOLD="0.02"  # $0.02/hour threshold
  
  if [ "$(echo "$OPENROUTER_HOURLY > $OPENROUTER_THRESHOLD" | bc -l)" -eq 1 ]; then
    DAILY_PROJ=$(echo "scale=2; $OPENROUTER_HOURLY * 24" | bc -l)
    MONTHLY_PROJ=$(echo "scale=2; $OPENROUTER_HOURLY * 24 * 30" | bc -l)
    send_alert "OpenRouter USAGE SPIKE!

Used: +\$$OPENROUTER_INCREASE in ${HOURS_ELAPSED}h
Rate: ~\$$OPENROUTER_HOURLY/hour

Projected:
- Daily: ~\$$DAILY_PROJ/day
- Monthly: ~\$$MONTHLY_PROJ/month

Total usage: \$$OPENROUTER_USAGE

⚠️  Possible causes:
- Gemini Direct API failed (fallback triggered)
- Heavy usage period
- Check fallback logs!"
  fi
fi

# ━━━ Save current state ━━━

cat > "$STATE_FILE" <<EOF
{
  "last_check_ts": $TIMESTAMP,
  "last_check_datetime": "$DATETIME",
  "providers": {
    "deepseek": {
      "balance": $DEEPSEEK_BALANCE,
      "used_since_last": $DEEPSEEK_USED,
      "hourly_rate": ${DEEPSEEK_HOURLY:-0}
    },
    "openrouter": {
      "usage": $OPENROUTER_USAGE,
      "increase_since_last": $OPENROUTER_INCREASE,
      "hourly_rate": ${OPENROUTER_HOURLY:-0}
    }
  },
  "thresholds": {
    "deepseek_hourly": $DEEPSEEK_THRESHOLD,
    "openrouter_hourly": $OPENROUTER_THRESHOLD
  }
}
EOF

# ━━━ Output summary ━━━

echo "━━━ Model Usage Monitor ━━━"
echo "Timestamp: $DATETIME"
echo ""
echo "DeepSeek:"
echo "  Balance: \$$DEEPSEEK_BALANCE"
echo "  Used (since last): \$$DEEPSEEK_USED"
echo "  Rate: ~\$${DEEPSEEK_HOURLY:-0}/hour"
echo ""
echo "OpenRouter:"
echo "  Total usage: \$$OPENROUTER_USAGE"
echo "  Increase: +\$$OPENROUTER_INCREASE"
echo "  Rate: ~\$${OPENROUTER_HOURLY:-0}/hour"
echo ""
echo "Time since last check: ${HOURS_ELAPSED}h"
echo ""
echo "State saved to: $STATE_FILE"

exit 0
