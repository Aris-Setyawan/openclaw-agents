#!/bin/bash
# Check API balances and alert if any is low
SCRIPT_DIR="$(dirname "$0")"

echo "💰 API Balance Check — $(date '+%Y-%m-%d %H:%M')"
output=$("$SCRIPT_DIR/check-all-balances.sh" 2>&1)
echo "$output"

# Alert if DeepSeek balance < $1
deepseek_bal=$(echo "$output" | grep -i "deepseek" | grep -oP '[\d.]+' | head -1)
if [ -n "$deepseek_bal" ] && [ "$(echo "$deepseek_bal < 1" | bc -l 2>/dev/null)" = "1" ]; then
    "$SCRIPT_DIR/telegram-send.sh" "" "⚠️ *LOW BALANCE ALERT*

💰 DeepSeek: \$$deepseek_bal
🔴 Balance below \$1 — top up soon!" 2>/dev/null
fi
