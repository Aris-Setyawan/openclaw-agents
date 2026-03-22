# Agent Models & Fallback Reference

**Generated:** 2026-03-22 10:51 UTC  
**Total Agents:** 9 (1 main + 8 specialized)

---

## 📊 Quick Reference Table

| Agent | Role | Primary Model | Provider | Cost/Call |
|-------|------|---------------|----------|-----------|
| **main** | TUI/Main Session | Claude Opus 4-5 | Anthropic | Paid |
| **agent1** | Telegram (YOU!) | **Gemini 2.5 Flash** | Google | **FREE** ✅ |
| **agent2** | Creative | DeepSeek Chat | DeepSeek | ~$0.001 |
| **agent3** | Analytical | Qwen 3 Max | ModelStudio | Active |
| **agent4** | Coding | Claude Opus 4-6 | Anthropic | Paid |
| **agent5** | Backup Agent1 | Claude Haiku 4-5 | Anthropic | Paid |
| **agent6** | Backup Agent2 | Qwen 3.5 Plus | ModelStudio | Active |
| **agent7** | Backup Agent3 | Qwen 3 Max | ModelStudio | Active |
| **agent8** | Backup Agent4 | Qwen 3 Coder Next | ModelStudio | Active |

---

## 🎯 Primary Agents (Active Daily)

### **AGENT1 - Orchestrator/Telegram Handler (YOU!)**

**Role:** Main Telegram interface, routing, coordination

**Primary Model:**
```
gemini/models/gemini-2.5-flash
```
- Provider: Google Direct API
- Cost: **FREE tier** ✅
- Speed: Fast
- Quality: Good for chat/coordination

**Fallback Chain:**
1. `deepseek/deepseek-chat`
2. `modelstudio/qwen3.5-plus`
3. `openrouter/google/gemini-2.5-flash`

**Current Status:** 
- ✅ Primary works perfectly (Gemini Direct)
- ✅ Fallback NEVER triggered (OpenRouter idle)
- ✅ Cost: $0/day

---

### **AGENT2 - Creative (Image/Video Generation)**

**Role:** Generate images, videos, creative content

**Primary Model:**
```
deepseek/deepseek-chat
```
- Provider: DeepSeek
- Cost: ~$0.001/call
- Note: **Context bloat risk!** (6M tokens in 2 days)

**Fallback Chain:**
1. `modelstudio/qwen3.5-plus`
2. `openrouter/google/gemini-2.5-flash`
3. `anthropic/claude-haiku-4-5`

**Actual Generation Tools:**
- **Images:** Google Gemini Imagen 3 (~Rp 1-5K)
- **Videos:** kie.ai Veo3 Fast (~Rp 12K, **NOT SETUP YET!**)
  - Fallback: Google Veo (~Rp 30K, **EXPENSIVE!**)
- **Audio:** Google Gemini TTS (~Rp 0.5-2K)

**Current Issues:**
- ⚠️ DeepSeek usage high (6M tokens/2 days)
- 🚨 kie.ai NOT configured (falls back to expensive Google Veo)
- ✅ MEMORY.md removed (saves 10% tokens)

---

### **AGENT3 - Analytical/Research/Data**

**Role:** Data analysis, research, complex reasoning

**Primary Model:**
```
modelstudio/qwen3-max-2026-01-23
```
- Provider: ModelStudio (Alibaba)
- Cost: Active (no public pricing)
- Quality: High for analytical tasks

**Fallback Chain:**
1. `deepseek/deepseek-reasoner` ⚠️ **EXPENSIVE! (~$0.005/call)**
2. `modelstudio/qwen3.5-plus`
3. `openrouter/google/gemini-2.5-flash`

**WARNING:**
- ⚠️ Fallback #1 (DeepSeek Reasoner) is **10x more expensive** than Chat!
- Only use for complex analytical tasks

---

### **AGENT4 - Technical/Coding/DevOps**

**Role:** Coding, debugging, infrastructure, technical tasks

**Primary Model:**
```
anthropic/claude-opus-4-6
```
- Provider: Anthropic
- Cost: Paid (Anthropic billing)
- Quality: Excellent for coding

**Fallback Chain:**
1. `anthropic/claude-haiku-4-5`
2. `modelstudio/qwen3-coder-next`
3. `deepseek/deepseek-chat`
4. `openrouter/google/gemini-2.5-flash`

**Usage:** Only when coding/technical tasks needed

---

## 🔄 Backup Agents (Failover)

### **AGENT5 - Backup for Agent1**
- Primary: Claude Haiku 4-5
- Role: Monitor/Supervisor
- Activates: When agent1 fails

### **AGENT6 - Backup for Agent2**
- Primary: Qwen 3.5 Plus
- Role: Creative Assistant
- Activates: When agent2 fails

### **AGENT7 - Backup for Agent3**
- Primary: Qwen 3 Max
- Role: Research Assistant
- Activates: When agent3 fails

### **AGENT8 - Backup for Agent4**
- Primary: Qwen 3 Coder Next
- Role: Tech Support
- Activates: When agent4 fails

---

## 💰 Cost Analysis

### **FREE:**
- ✅ Agent1 (Gemini 2.5 Flash via Google Direct)

### **CHEAP (<$0.01/day):**
- ✅ Agent2 (DeepSeek Chat) - **IF optimized**
- ✅ Agent3 (Qwen 3 Max)
- ✅ Agent6-8 (Qwen models)

### **MODERATE ($0.10-1/day):**
- ⚠️ Agent2 (DeepSeek Chat) - **CURRENT state with context bloat**

### **EXPENSIVE (>$1/day):**
- 🚨 Image/Video generation (Google Veo/Imagen)
- 🚨 Agent3 fallback (DeepSeek Reasoner)
- 🚨 Agent4/5 (Claude Opus/Haiku)

---

## 🎯 Optimization Priorities

### **1. URGENT: Setup kie.ai API Key**
- Current: Video gen defaults to Google Veo (~Rp 30K)
- After: Use kie.ai Veo3 Fast (~Rp 12K)
- **Savings: Rp 18K per video** (60%!)

### **2. DONE: DeepSeek Context Reduction**
- ✅ Removed MEMORY.md from agent2/3
- Savings: ~200K tokens/day (-10%)

### **3. TODO: Limit Agent3 Reasoner Usage**
- DeepSeek Reasoner 10x more expensive than Chat
- Only use for truly complex tasks
- Default to Qwen 3 Max (primary) instead

### **4. TODO: Use Direct Scripts**
- `generate-image-direct.sh` (bypass agent context)
- `generate-video-direct.sh` (bypass agent context)
- Saves: ~12K tokens per generation

---

## 📚 Files & References

- Configuration: `~/.openclaw/agents/*/agent/`
- Auth profiles: `~/.openclaw/agents/agent1/agent/auth-profiles.json`
- Models config: `~/.openclaw/agents/*/agent/models.json`
- This reference: `/root/.openclaw/workspace/docs/AGENT-MODELS-REFERENCE.md`

---

## 🔍 Check Commands

```bash
# List all agents & models
openclaw config get agents.list | jq -r '.[] | "\(.id): \(.model.primary)"'

# Check specific agent
openclaw config get agents.list | jq '.[] | select(.id == "agent2")'

# Check API balances
/root/.openclaw/workspace/scripts/check-all-balances.sh

# Check API usage
/root/.openclaw/workspace/scripts/check-api-health.sh 24
```

---

**Last Updated:** 2026-03-22 by Santa (Agent1) 🧑‍🎄
