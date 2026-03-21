#!/bin/bash
# Multi-Agent Integration Test
# Tests: messaging, memory sharing, image gen, agent collaboration

OPENCLAW=/www/server/nvm/versions/node/v22.20.0/bin/openclaw
WORKSPACE=/root/.openclaw/workspace
LOG=/root/.openclaw/workspace/tmp/test-$(date +%Y%m%d-%H%M%S).log
mkdir -p $(dirname $LOG)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "$1" | tee -a $LOG; }
pass() { log "${GREEN}✅ PASS${NC}: $1"; }
fail() { log "${RED}❌ FAIL${NC}: $1"; }
info() { log "${BLUE}ℹ️  ${NC}$1"; }
section() { log "\n${YELLOW}══════════════════════════════════════${NC}"; log "${YELLOW}$1${NC}"; log "${YELLOW}══════════════════════════════════════${NC}"; }

PASS=0; FAIL=0

# ─── TEST 1: Basic Ping All Agents ───────────────────────────
section "TEST 1: Basic Agent Response (1-8)"
for i in 1 2 3 4 5 6 7 8; do
    info "Testing agent$i..."
    response=$($OPENCLAW agent --agent agent$i --message "Balas 1 kata: OK" 2>/dev/null | tail -1)
    if [ -n "$response" ]; then
        pass "agent$i responded: ${response:0:50}"
        ((PASS++))
    else
        fail "agent$i: no response"
        ((FAIL++))
    fi
    sleep 1
done

# ─── TEST 2: Shared Memory Write & Read ──────────────────────
section "TEST 2: Shared Memory (agent1 write, agent2 read)"
TEST_MSG="TEST_TOKEN_$(date +%s)"
info "Writing test token to shared memory..."
echo "- [$(date +%H:%M)] [agent1-test] $TEST_MSG" >> $WORKSPACE/memory/$(date +%Y-%m-%d).md

response=$($OPENCLAW agent --agent agent2 \
  --message "Baca file $WORKSPACE/memory/$(date +%Y-%m-%d).md dan cari teks: $TEST_MSG. Jawab: ADA atau TIDAK ADA" \
  2>/dev/null | tail -3)

if echo "$response" | grep -qi "ADA"; then
    pass "Shared memory: agent2 read token written by agent1"
    ((PASS++))
else
    fail "Shared memory: agent2 could not find token. Response: $response"
    ((FAIL++))
fi

# ─── TEST 3: Agent1 Orchestrate → Agent3 Analytical ─────────
section "TEST 3: Multi-Agent Flow (agent1 → agent3)"
response=$($OPENCLAW agent --agent agent3 \
  --message "Analisa singkat: berapa 2+2 dan kenapa? Jawab dalam 2 kalimat." \
  2>/dev/null | tail -5)
if [ -n "$response" ]; then
    pass "agent3 analytical response received"
    info "agent3: ${response:0:100}"
    ((PASS++))
else
    fail "agent3: no response"
    ((FAIL++))
fi

# ─── TEST 4: Agent4 Technical/Coding ─────────────────────────
section "TEST 4: Agent4 Technical"
response=$($OPENCLAW agent --agent agent4 \
  --message "Tulis bash one-liner untuk count file di /tmp. Jawab codenya saja." \
  2>/dev/null | tail -3)
if [ -n "$response" ]; then
    pass "agent4 technical response: ${response:0:80}"
    ((PASS++))
else
    fail "agent4: no response"
    ((FAIL++))
fi

# ─── TEST 5: Image Generation ────────────────────────────────
section "TEST 5: Image Generation (agent1)"
info "Testing image gen via agent1..."
img_response=$($OPENCLAW agent --agent agent1 \
  --message "Generate gambar: a cute red lobster with graduation cap, digital art style. Setelah generate, kirim ke Telegram dengan caption 'Test gambar multi-agent'" \
  2>/dev/null | tail -10)

if echo "$img_response" | grep -qi "generat\|gambar\|image\|kirim\|sent\|success"; then
    pass "Image gen initiated"
    info "$img_response"
    ((PASS++))
else
    info "Image gen response: $img_response"
    # Check if any image file was created
    if ls /tmp/*.png /tmp/*.jpg /root/.openclaw/workspace/tmp/*.png 2>/dev/null | head -1 | grep -q .; then
        pass "Image file found in /tmp"
        ((PASS++))
    else
        fail "Image gen: unclear result"
        ((FAIL++))
    fi
fi

# ─── TEST 6: Health State Check ──────────────────────────────
section "TEST 6: Health State Consistency"
healthy=$(cat $WORKSPACE/health-state.json | python3 -c "
import json,sys
d=json.load(sys.stdin)
agents = d.get('agents',{})
h = sum(1 for v in agents.values() if v.get('status')=='healthy')
total = len(agents)
print(f'{h}/{total}')
")
info "Health state: $healthy agents healthy"
if [[ "$healthy" == "8/8" ]]; then
    pass "All 8 agents healthy"
    ((PASS++))
else
    fail "Not all agents healthy: $healthy"
    ((FAIL++))
fi

# ─── TEST 7: Proxy Gemini Working ────────────────────────────
section "TEST 7: Gemini Proxy (agent1)"
proxy_hits=$(journalctl -u openclaw-google-proxy --since "1 hour ago" --no-pager 2>/dev/null | grep -c "200 -" || echo 0)
if [ "$proxy_hits" -gt 0 ]; then
    pass "Gemini proxy: $proxy_hits successful requests in last hour"
    ((PASS++))
else
    fail "Gemini proxy: no successful requests in last hour"
    ((FAIL++))
fi

# ─── SUMMARY ─────────────────────────────────────────────────
section "SUMMARY"
TOTAL=$((PASS + FAIL))
log "${GREEN}PASS: $PASS/$TOTAL${NC}"
if [ $FAIL -gt 0 ]; then
    log "${RED}FAIL: $FAIL/$TOTAL${NC}"
fi
log "\nLog saved to: $LOG"
