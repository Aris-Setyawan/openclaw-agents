#!/bin/bash
# OpenRouter Cost Calculator from Session Usage
# Calculates token usage cost based on actual session data

API_KEY=$(python3 -c "import json; d=json.load(open('$HOME/.openclaw/agents/main/agent/auth-profiles.json')); print(d['profiles'].get('openrouter:default',{}).get('key',''))" 2>/dev/null)

if [ -z "$API_KEY" ]; then
  echo "❌ OpenRouter API key not found"
  exit 1
fi

echo "🧮 OpenRouter Cost Calculator"
echo "=============================="
echo ""

# Get current usage from API
RESPONSE=$(curl -s https://openrouter.ai/api/v1/auth/key \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json")

if echo "$RESPONSE" | grep -q '"usage"'; then
  TOTAL_USAGE=$(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['data']['usage'])")
  TOTAL_LIMIT=$(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); limit=d['data'].get('limit'); print(limit if limit else 'unlimited')")
  
  echo "📊 OpenRouter Account Status:"
  echo "  Total Usage (all-time): \$$TOTAL_USAGE"
  echo "  Account Limit: \$$TOTAL_LIMIT"
  
  # Manual calculation from sesi ini
  echo ""
  echo "💰 Estimated Session Cost (mas Aris mention):"
  echo "  Current Balance: \$4.31 / \$5.00"
  echo "  Used: \$0.69"
  echo ""
  echo "📈 Cost Breakdown Estimate:"
  echo "  - If mostly Haiku (cheap): ~1.5M tokens used"
  echo "  - If mostly Sonnet (mid): ~300K tokens used"
  echo "  - If mostly Opus (expensive): ~150K tokens used"
  echo ""
  echo "🔢 Usage Today: $TOTAL_USAGE"
  echo ""
else
  echo "❌ Error fetching usage: $RESPONSE"
  exit 1
fi

# Monthly projection
echo "📅 Monthly Projection (if usage continues):"
DAILY_USAGE=$(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['data'].get('usage_daily', 0))")
MONTHLY_EST=$(python3 -c "print(round($DAILY_USAGE * 30, 2))")

echo "  Daily avg: \$$DAILY_USAGE"
echo "  Monthly est: ~\$$MONTHLY_EST"

if (( $(echo "$MONTHLY_EST > 5" | bc -l) )); then
  echo "  ⚠️  WARNING: Monthly usage exceeds \$5 credit"
else
  echo "  ✅ Safe within \$5 monthly budget"
fi

echo ""
echo "=============================="
