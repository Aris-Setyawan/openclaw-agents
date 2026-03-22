#!/bin/bash
# Dashboard API health - detect loops, rate spikes, errors
# Usage: check-api-health.sh [hours_to_check]

HOURS="${1:-24}"
LOG_FILE="/root/.openclaw/workspace/logs/api-usage.log"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 API HEALTH CHECK - Last $HOURS hours"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ ! -f "$LOG_FILE" ]; then
  echo "✅ No API usage logged yet (clean state)"
  exit 0
fi

CUTOFF=$(date -u -d "$HOURS hours ago" +"%Y-%m-%d %H:%M" 2>/dev/null || date -u -v-${HOURS}H +"%Y-%m-%d %H:%M")

echo "=== Request Summary ==="
TOTAL=$(grep -c "" "$LOG_FILE" 2>/dev/null || echo 0)
RECENT=$(awk -v cutoff="$CUTOFF" '$0 > cutoff' "$LOG_FILE" 2>/dev/null | wc -l)
IMAGES=$(grep "image" "$LOG_FILE" 2>/dev/null | wc -l)
VIDEOS=$(grep "video" "$LOG_FILE" 2>/dev/null | wc -l)
ALERTS=$(grep "ALERT" "$LOG_FILE" 2>/dev/null | wc -l)

echo "  Total requests (all time): $TOTAL"
echo "  Recent requests ($HOURS hrs): $RECENT"
echo "  Images: $IMAGES"
echo "  Videos: $VIDEOS"
echo "  ⚠️  Alerts (rate spikes): $ALERTS"
echo ""

if [ "$ALERTS" -gt 0 ]; then
  echo "=== Recent Alerts ==="
  grep "ALERT" "$LOG_FILE" | tail -5
  echo ""
fi

echo "=== Request Rate (per hour) ==="
awk -v cutoff="$CUTOFF" '$0 > cutoff {print $1, $2}' "$LOG_FILE" 2>/dev/null | \
  cut -d':' -f1 | sort | uniq -c | tail -10 | \
  awk '{printf "  %s:00 — %d requests\n", $2" "$3, $1}'

echo ""
echo "=== Provider Breakdown ==="
grep -v "ALERT" "$LOG_FILE" 2>/dev/null | awk '{print $NF}' | sort | uniq -c | sort -rn | \
  awk '{printf "  %-15s: %d\n", $2, $1}'

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$ALERTS" -gt 3 ]; then
  echo "🚨 WARNING: Multiple rate spike alerts detected!"
  echo "   Check for loops or automated retries."
fi

exit 0
