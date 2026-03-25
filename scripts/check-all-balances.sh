#!/bin/bash
# Check API balances for all configured providers

OPENCLAW_DIR="/root/.openclaw"

# Cari key dari semua agent — ambil nilai pertama yang ditemukan
get_key() {
    local profile="$1" field="$2"
    for auth in "$OPENCLAW_DIR"/agents/*/agent/auth-profiles.json; do
        val=$(python3 -c "
import json, sys
try:
    d = json.load(open('$auth'))
    v = d.get('profiles',{}).get('$profile',{}).get('$field','')
    if v: print(v)
except: pass
" 2>/dev/null)
        if [ -n "$val" ]; then echo "$val"; return; fi
    done
}

DEEPSEEK_KEY=$(get_key "deepseek:default" "token")
OPENROUTER_KEY=$(get_key "openrouter:default" "key")
ANTHROPIC_KEY=$(get_key "anthropic:default" "token")
MODELSTUDIO_KEY=$(get_key "modelstudio:default" "key")
GOOGLE_KEY=$(get_key "google:default" "key")
KIE_KEY=$(get_key "kieai:default" "key")

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
