#!/bin/bash
# Check API balances for all configured providers

AUTH_FILE="/root/.openclaw/agents/agent1/agent/auth-profiles.json"

# --- Load Keys (ensure they are available) ---
DEEPSEEK_KEY=$(python3 -c "import json; d=json.load(open('$AUTH_FILE')); print(d['profiles'].get('deepseek:default',{}).get('token',''))" 2>/dev/null)
OPENROUTER_KEY=$(python3 -c "import json; d=json.load(open('$AUTH_FILE')); print(d['profiles'].get('openrouter:default',{}).get('key',''))" 2>/dev/null)
ANTHROPIC_KEY=$(python3 -c "import json; d=json.load(open('$AUTH_FILE')); print(d['profiles'].get('anthropic:default',{}).get('token',''))" 2>/dev/null)
MODELSTUDIO_KEY=$(python3 -c "import json; d=json.load(open('$AUTH_FILE')); print(d['profiles'].get('modelstudio:default',{}).get('key',''))" 2>/dev/null)
GOOGLE_KEY=$(python3 -c "import json; d=json.load(open('$AUTH_FILE')); print(d['profiles'].get('google:default',{}).get('key',''))" 2>/dev/null)
KIE_KEY=$(python3 -c "import json; d=json.load(open('$AUTH_FILE')); print(d['profiles'].get('kieai:default',{}).get('key',''))" 2>/dev/null)

# --- Colors for better output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}💰 API BALANCE CHECK - $(date -u '+%Y-%m-%d %H:%M UTC')${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# DeepSeek Balance
echo -e "${YELLOW}🎅 DeepSeek:${NC}"
if [ -n "$DEEPSEEK_KEY" ]; then
    BALANCE=$(curl -s "https://api.deepseek.com/user/balance" \
        -H "Authorization: Bearer $DEEPSEEK_KEY" 2>/dev/null | jq -r '.balance_infos[0].total_balance // "error"' )
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
    USAGE=$(echo "$RESULT" | jq -r '.data.usage // "error"' )
    LIMIT=$(echo "$RESULT" | jq -r '.data.limit // "unlimited"' )
    
    if [ "$USAGE" != "error" ]; then
        echo -e "   Usage: ${GREEN}\$${USAGE}${NC}"
        echo -e "   Limit: ${GREEN}${LIMIT}${NC}"
    else
        echo -e "   ${RED}⚠ Could not fetch usage${NC}"
    fi
else
    echo -e "   ${RED}❌ Key not configured${NC}"
fi
echo ""

# Anthropic Token Status
echo -e "${YELLOW}🎅 Anthropic:${NC}"
if [ -n "$ANTHROPIC_KEY" ]; then
    echo -e "   ${GREEN}✅ Token present (balance check not available via API)${NC}"
else
    echo -e "   ${RED}❌ Key not configured${NC}"
fi
echo ""

# ModelStudio (Alibaba) Key Status
echo -e "${YELLOW}🎅 ModelStudio (Alibaba):${NC}"
if [ -n "$MODELSTUDIO_KEY" ]; then
    echo -e "   ${GREEN}✅ Key present: ${MODELSTUDIO_KEY:0:20}...${NC}"
    echo -e "   No direct balance check API available"
else
    echo -e "   ${RED}❌ Key not configured${NC}"
fi
echo ""

# Google Gemini/Veo Status
echo -e "${YELLOW}🎅 Google Gemini/Veo:${NC}"
if [ -n "$GOOGLE_KEY" ]; then
  echo -e "   ${GREEN}✅ Key present: ${GOOGLE_KEY:0:20}...${NC}"
  echo -e "   ⚠️  Free tier API (generativelanguage.googleapis.com)"
  echo -e "   Vertex AI billing (Imagen/Veo): Check Google Cloud Console"
  echo -e "   → https://console.cloud.google.com/billing"
else
  echo -e "   ${RED}❌ Key not configured${NC}"
fi
echo ""

# kie.ai Status
echo -e "${YELLOW}🎅 kie.ai:${NC}"
if [ -n "$KIE_KEY" ]; then
  echo -e "   ${GREEN}✅ Key present: ${KIE_KEY:0:20}...${NC}"
  echo -e "   No direct balance check API available"
else
  echo -e "   ${RED}❌ API key not configured${NC}"
  echo -e "   To setup: Signup at https://kie.ai"
fi
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "⏱️  Waktu cek: $(TZ=Asia/Jakarta date '+%Y-%m-%d %H:%M WIB') / $(date -u '+%H:%M UTC')"
