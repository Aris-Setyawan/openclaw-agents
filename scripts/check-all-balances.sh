#!/bin/bash
# Check API balances - reads from OpenClaw credentials
# Usage: ./check-all-balances.sh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Read keys from OpenClaw credentials
AUTH_FILE="$HOME/.openclaw/agents/main/agent/auth-profiles.json"

if [ ! -f "$AUTH_FILE" ]; then
    echo -e "${RED}❌ Auth profiles not found: $AUTH_FILE${NC}"
    exit 1
fi

OPENROUTER_KEY=$(jq -r '.profiles."openrouter:default".key // empty' "$AUTH_FILE")
DEEPSEEK_KEY=$(jq -r '.profiles."deepseek:default".token // empty' "$AUTH_FILE")
ANTHROPIC_KEY=$(jq -r '.profiles."anthropic:default".token // empty' "$AUTH_FILE")

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎄 API Balance Checker (OpenClaw Edition)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# DeepSeek Balance
echo -e "${YELLOW}🦌 DeepSeek:${NC}"
if [ -n "$DEEPSEEK_KEY" ]; then
    BALANCE=$(curl -s "https://api.deepseek.com/user/balance" \
        -H "Authorization: Bearer $DEEPSEEK_KEY" 2>/dev/null | jq -r '.balance_infos[0].total_balance // "error"')
    if [ "$BALANCE" != "error" ] && [ "$BALANCE" != "null" ]; then
        echo -e "   Balance: ${GREEN}\$${BALANCE}${NC}"
    else
        echo -e "   ${RED}⚠ Could not fetch balance${NC}"
    fi
else
    echo -e "   ${RED}❌ Key not configured${NC}"
fi
echo ""

# OpenRouter Balance
echo -e "${YELLOW}🎅 OpenRouter:${NC}"
if [ -n "$OPENROUTER_KEY" ]; then
    RESULT=$(curl -s "https://openrouter.ai/api/v1/auth/key" \
        -H "Authorization: Bearer $OPENROUTER_KEY" 2>/dev/null)
    USAGE=$(echo "$RESULT" | jq -r '.data.usage // "error"')
    LIMIT=$(echo "$RESULT" | jq -r '.data.limit // "unlimited"')
    if [ "$USAGE" != "error" ] && [ "$USAGE" != "null" ]; then
        echo -e "   Used: ${GREEN}\$${USAGE}${NC}"
        if [ "$LIMIT" != "null" ] && [ "$LIMIT" != "unlimited" ]; then
            echo -e "   Limit: \$${LIMIT}"
        else
            echo -e "   Limit: ${GREEN}Unlimited (pay-as-you-go)${NC}"
        fi
    else
        echo -e "   ${RED}⚠ Could not fetch balance${NC}"
    fi
else
    echo -e "   ${RED}❌ Key not configured${NC}"
fi
echo ""

# Anthropic (no public balance API, just verify key works)
echo -e "${YELLOW}🤖 Anthropic:${NC}"
if [ -n "$ANTHROPIC_KEY" ]; then
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://api.anthropic.com/v1/messages" \
        -H "x-api-key: $ANTHROPIC_KEY" \
        -H "anthropic-version: 2023-06-01" \
        -H "content-type: application/json" \
        -d '{"model":"claude-3-haiku-20240307","max_tokens":1,"messages":[{"role":"user","content":"hi"}]}' 2>/dev/null)
    if [ "$STATUS" = "200" ]; then
        echo -e "   Status: ${GREEN}✅ Key valid & working${NC}"
    elif [ "$STATUS" = "401" ]; then
        echo -e "   Status: ${RED}❌ Invalid key${NC}"
    elif [ "$STATUS" = "529" ] || [ "$STATUS" = "503" ] || [ "$STATUS" = "502" ]; then
        echo -e "   Status: ${YELLOW}⚠ API overloaded (key valid)${NC}"
    else
        echo -e "   Status: ${YELLOW}⚠ HTTP $STATUS${NC}"
    fi
else
    echo -e "   ${RED}❌ Key not configured${NC}"
fi
echo ""

# ModelStudio/DashScope - test API
echo -e "${YELLOW}🎋 ModelStudio (DashScope):${NC}"
MODELSTUDIO_KEY=$(jq -r '.providers.modelstudio.apiKey // empty' "$HOME/.openclaw/agents/main/agent/models.json" 2>/dev/null)
if [ -n "$MODELSTUDIO_KEY" ]; then
    STATUS=$(curl -s --max-time 5 "https://dashscope-intl.aliyuncs.com/compatible-mode/v1/chat/completions" \
        -H "Authorization: Bearer $MODELSTUDIO_KEY" \
        -H "Content-Type: application/json" \
        -d '{"model":"qwen-turbo","messages":[{"role":"user","content":"hi"}],"max_tokens":1}' 2>/dev/null | jq -r '.choices[0].message.content // "error"')
    if [ "$STATUS" != "error" ] && [ "$STATUS" != "null" ] && [ -n "$STATUS" ]; then
        echo -e "   Status: ${GREEN}✅ Key valid & working${NC}"
    else
        echo -e "   Status: ${RED}⚠ API error or invalid key${NC}"
    fi
else
    echo -e "   ${RED}❌ Key not configured${NC}"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Done! 🧑‍🎄"
