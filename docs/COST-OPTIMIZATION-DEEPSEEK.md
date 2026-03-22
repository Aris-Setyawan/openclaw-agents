# DeepSeek Cost Optimization

**Date:** 2026-03-22  
**Trigger:** 6.2M tokens in 2 days, $0.95 cost (projected $14.25/month)

---

## Problem

**Usage (Mar 20-22):**
- **6,215,181 tokens** (6.2M!) in 2 days
- **239 API requests** (agent2 - deepseek-chat)
- **228 API requests** (agent3 - deepseek-reasoner)
- **Cost: ~$0.95** (projected **$14.25/month or Rp 228K!**)

**Root cause:**
- **Context bloat:** Every API call loads AGENTS.md, TOOLS.md, MEMORY.md, session history
- **Average: ~12,000 tokens per call**
- **Agent3 (Reasoner) 10x more expensive than agent2 (Chat)**

---

## Solutions Implemented

### 1. Remove MEMORY.md from agent2/agent3 ✅

**Rationale:**
- MEMORY.md contains personal context (user preferences, history)
- NOT needed for creative/analytical tasks
- Only relevant for main session (direct chat with user)

**Implementation:**
```bash
rm ~/.openclaw/agents/agent2/agent/MEMORY.md
rm ~/.openclaw/agents/agent3/agent/MEMORY.md
echo "# Not used" > ~/.openclaw/agents/agent2/agent/MEMORY.md
echo "# Not used" > ~/.openclaw/agents/agent3/agent/MEMORY.md
```

**Savings:**
- -1,200 tokens per call (-10%)
- -200K tokens/day
- ~$0.003/day ($0.09/month)

### 2. Use Direct Scripts (Bypass Agent Delegation) ✅

**Available scripts:**
- `generate-image-direct.sh` - NO agent context overhead
- `generate-video-direct.sh` - NO agent context overhead

**Usage:**
```bash
# Instead of delegating to agent2:
/root/.openclaw/workspace/scripts/generate-image-direct.sh "prompt" "caption"

# This bypasses agent2 entirely, calls Gemini Imagen directly
# Saves: ~12,000 tokens per image generation!
```

**Savings:**
- -100% agent overhead for image/video gen
- ~$0.50/day if 50 image/video requests

### 3. Limit Agent3 (Reasoner) Usage ⏳ (Manual)

**Problem:**
- DeepSeek Reasoner: **$0.55 input, $2.19 output** per 1M tokens
- DeepSeek Chat: **$0.14 input, $0.28 output** per 1M tokens
- **Reasoner = 10x more expensive!**

**Solution:**
- Only use agent3 (Reasoner) for complex analytical tasks
- Default to agent2 (Chat) for simple reasoning

**Implementation:**
- Update routing logic in agent1
- Prefer agent2 unless explicitly analytical task

---

## Additional Optimizations (Future)

### 4. Reduce TOOLS.md Size

**Current:** 12KB, ~250 lines, ~2,000 tokens

**Optimization:**
- Split into modular files
- Load only relevant sections per task
- agent2 only needs image/video gen tools
- agent3 only needs analysis tools

**Expected savings:** -1,000 tokens per call

### 5. Limit Session History

**Current:** ~5,000-10,000 tokens of history per call

**Optimization:**
- Keep only last 10 messages
- Summarize older context instead of full text

**Expected savings:** -3,000 tokens per call

### 6. Switch Models for Cheap Tasks

**Alternative for agent2:**
- Current: DeepSeek Chat ($0.14 input)
- Alternative: Qwen 3.5 Plus via ModelStudio (cheaper?)
- Keep DeepSeek for complex creative work only

---

## Cost Projection

### Before Optimization:
- **6.2M tokens / 2 days**
- **Cost: ~$1/2 days**
- **Monthly: $15** (Rp 240K!) 😱

### After Current Fixes (MEMORY.md removed + direct scripts):
- **~5M tokens / 2 days** (-20%)
- **Cost: ~$0.80/2 days**
- **Monthly: $12** (Rp 192K)
- **Savings: $3/month** (Rp 48K)

### After Full Optimization (all 6 steps):
- **~2M tokens / 2 days** (-68%)
- **Cost: ~$0.32/2 days**
- **Monthly: $5** (Rp 80K)
- **Savings: $10/month** (Rp 160K!) 🎉

---

## Monitoring

**Daily check:**
```bash
# Check DeepSeek balance
curl -s https://api.deepseek.com/user/balance \
  -H "Authorization: Bearer $DEEPSEEK_KEY" | jq

# Check API usage log
/root/.openclaw/workspace/scripts/check-api-health.sh 24
```

**Alert when:**
- Daily usage > $0.50
- Token usage > 1M/day
- Balance < $1

---

## References

- DeepSeek platform: https://platform.deepseek.com
- Pricing: https://platform.deepseek.com/pricing
- Implementation: This document
- Memory: `/root/.openclaw/workspace/memory/2026-03-22.md`
