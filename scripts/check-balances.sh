#!/bin/bash
# Check AI Provider Balances
# Usage: ./check-balances.sh

AUTH_FILE="$HOME/.openclaw/agents/main/agent/auth-profiles.json"

if [ ! -f "$AUTH_FILE" ]; then
  echo "❌ Auth file not found: $AUTH_FILE"
  exit 1
fi

echo "🔍 Checking AI Provider Balances"
echo "================================"

# DeepSeek Balance
DEEPSEEK_TOKEN=$(python3 -c "import json; d=json.load(open('$AUTH_FILE')); print(d['profiles'].get('deepseek:default',{}).get('token',''))" 2>/dev/null)

if [ -n "$DEEPSEEK_TOKEN" ]; then
  echo ""
  echo "💰 DeepSeek:"
  DEEPSEEK_RESP=$(curl -s https://api.deepseek.com/user/balance \
    -H "Authorization: Bearer $DEEPSEEK_TOKEN" \
    -H "Content-Type: application/json")
  
  if echo "$DEEPSEEK_RESP" | grep -q "is_available"; then
    python3 -c "
import json
d = json.loads('$DEEPSEEK_RESP')
b = d['balance_infos'][0]
print(f\"  Total: \${b['total_balance']} {b['currency']}\")
print(f\"  Granted: \${b['granted_balance']}\")
print(f\"  Topped up: \${b['topped_up_balance']}\")
"
  else
    echo "  ❌ Error: $DEEPSEEK_RESP"
  fi
else
  echo ""
  echo "💰 DeepSeek: ⚪ Not configured"
fi

# OpenRouter Usage
OPENROUTER_KEY=$(python3 -c "import json; d=json.load(open('$AUTH_FILE')); print(d['profiles'].get('openrouter:default',{}).get('key',''))" 2>/dev/null)

if [ -n "$OPENROUTER_KEY" ]; then
  echo ""
  echo "🌐 OpenRouter:"
  OR_RESP=$(curl -s https://openrouter.ai/api/v1/auth/key \
    -H "Authorization: Bearer $OPENROUTER_KEY" \
    -H "Content-Type: application/json")
  
  if echo "$OR_RESP" | grep -q "usage"; then
    python3 -c "
import json
d = json.loads('$OR_RESP')
data = d['data']
print(f\"  Usage (Total):    \${data['usage']:.4f}\")
print(f\"  Usage (Today):    \${data['usage_daily']:.4f}\")
print(f\"  Usage (Weekly):   \${data['usage_weekly']:.4f}\")
print(f\"  Usage (Monthly):  \${data['usage_monthly']:.4f}\")
print(f\"  BYOK Usage:       \${data['byok_usage']:.4f}\")
if data.get('limit'):
  print(f\"  Limit:            \${data['limit']}\")
  remaining = data['limit'] - data['usage']
  print(f\"  Remaining:        \${remaining:.4f}\")
else:
  print(f\"  Limit:            Unlimited (pay-as-you-go)\")
"
  else
    echo "  ❌ Error: $OR_RESP"
  fi
else
  echo ""
  echo "🌐 OpenRouter: ⚪ Not configured"
fi

echo ""
echo "================================"
