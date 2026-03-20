#!/bin/bash
# DeepSeek Balance Checker
# Usage: ./deepseek-balance.sh

API_KEY=$(cat ~/.openclaw/credentials/auth-profiles.json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('deepseek:default',{}).get('token',''))" 2>/dev/null)

if [ -z "$API_KEY" ]; then
  echo "❌ DeepSeek API key not found"
  exit 1
fi

RESPONSE=$(curl -s https://api.deepseek.com/user/balance \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json")

if echo "$RESPONSE" | grep -q "is_available"; then
  BALANCE=$(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); b=d['balance_infos'][0]; print(f\"💰 DeepSeek Balance: \${b['total_balance']} {b['currency']}\nGranted: \${b['granted_balance']}\nTopped up: \${b['topped_up_balance']}\")")
  echo "$BALANCE"
else
  echo "❌ Error: $RESPONSE"
fi
