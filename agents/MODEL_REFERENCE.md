# Model Reference — OpenClaw

> Referensi lengkap model yang tersedia. Gunakan format `provider/model-id` di openclaw.json.
> Untuk OpenRouter, prefix `openrouter/` sebelum model ID. Contoh: `openrouter/google/gemini-3-flash-preview`
> Last updated: 2026-03-20

---

## 🟢 Google (Direct API)

Format: `google/models/MODEL_ID` | Auth: `GOOGLE_API_KEY`

> ⚠️ Gunakan `models/` prefix. Gemini 2.5+ butuh `max_completion_tokens` — perlu LiteLLM proxy.

```
google/models/gemini-3-flash-preview       ← Terbaru, max_tokens OK ✓
google/models/gemini-3.1-flash-lite-preview
google/models/gemini-3.1-pro-preview
google/models/gemini-2.5-flash             ← Butuh max_completion_tokens ✗
google/models/gemini-2.5-flash-lite
google/models/gemini-2.5-pro
google/models/gemini-flash-latest
google/models/gemini-flash-lite-latest
google/models/gemini-pro-latest
```

**Via OpenRouter** (lebih stabil, handle API compat):
```
openrouter/google/gemini-3-flash-preview
openrouter/google/gemini-3.1-flash-lite-preview
openrouter/google/gemini-3.1-pro-preview
openrouter/google/gemini-2.5-flash          ← Agent1 primary sekarang
openrouter/google/gemini-2.5-flash-lite
openrouter/google/gemini-2.5-pro
openrouter/google/gemini-2.5-pro-preview
```

---

## 🟠 Anthropic (Direct API)

Format: `anthropic/MODEL_ID` | Auth: `ANTHROPIC_API_KEY`

```
anthropic/claude-opus-4-6      ← Agent4 primary (terkuat)
anthropic/claude-sonnet-4-6
anthropic/claude-haiku-4-5     ← Agent5 primary (cepat, murah)
anthropic/claude-opus-4-5
anthropic/claude-sonnet-4-5
```

**Via OpenRouter:**
```
openrouter/anthropic/claude-sonnet-4.6
openrouter/anthropic/claude-opus-4.6
openrouter/anthropic/claude-opus-4.5
openrouter/anthropic/claude-haiku-4.5
openrouter/anthropic/claude-sonnet-4.5
```

---

## 🔵 DeepSeek (Direct API)

Format: `deepseek/MODEL_ID` | Auth: `DEEPSEEK_API_KEY`

```
deepseek/deepseek-chat          ← Agent2 primary (output murah)
deepseek/deepseek-reasoner      ← Agent3 primary (reasoning)
```

**Via OpenRouter:**
```
openrouter/deepseek/deepseek-v3.2
openrouter/deepseek/deepseek-v3.2-speciale
openrouter/deepseek/deepseek-chat-v3.1
openrouter/deepseek/deepseek-r1-0528
openrouter/deepseek/deepseek-r1
openrouter/deepseek/deepseek-chat
openrouter/deepseek/deepseek-r1-distill-qwen-32b
```

---

## 🟣 ModelStudio / Alibaba Qwen (Direct API)

Format: `modelstudio/MODEL_ID` | Auth: `DASHSCOPE_API_KEY`

```
modelstudio/qwen3.5-plus        ← Agent6 primary
modelstudio/qwen3-max           ← Agent7 primary
modelstudio/qwen3-max-2026-01-23
modelstudio/qwen3-coder-next    ← Agent8 primary
modelstudio/qwen3-coder-plus
modelstudio/MiniMax-M2.5
modelstudio/glm-5
modelstudio/glm-4.7
modelstudio/kimi-k2.5
```

**Via OpenRouter:**
```
openrouter/qwen/qwen3.5-397b-a17b
openrouter/qwen/qwen3.5-122b-a10b
openrouter/qwen/qwen3.5-27b
openrouter/qwen/qwen3.5-35b-a3b
openrouter/qwen/qwen3.5-9b
openrouter/qwen/qwen3.5-flash-02-23
openrouter/qwen/qwen3.5-plus-02-15
openrouter/qwen/qwen3-max-thinking
openrouter/qwen/qwen3-coder-next
openrouter/qwen/qwen3-vl-32b-instruct
```

---

## ⚡ Z-AI / GLM (Via OpenRouter)

```
openrouter/z-ai/glm-5-turbo
openrouter/z-ai/glm-5
openrouter/z-ai/glm-4.7-flash   ← Cepat, murah
openrouter/z-ai/glm-4.7
openrouter/z-ai/glm-4.6v
openrouter/z-ai/glm-4.5
openrouter/z-ai/glm-4.5-air:free
openrouter/z-ai/glm-4.5-air
```

---

## 🌊 MiniMax (Via OpenRouter)

```
openrouter/minimax/minimax-m2.7
openrouter/minimax/minimax-m2.5
openrouter/minimax/minimax-m2.5:free
openrouter/minimax/minimax-m2
openrouter/minimax/minimax-m2-her
openrouter/minimax/minimax-m1
openrouter/minimax/minimax-01
```

---

## 🦙 Meta LLaMA (Via OpenRouter)

```
openrouter/meta-llama/llama-4-maverick
openrouter/meta-llama/llama-4-scout
openrouter/meta-llama/llama-3.3-70b-instruct
openrouter/meta-llama/llama-3.3-70b-instruct:free
openrouter/meta-llama/llama-3.1-405b
openrouter/meta-llama/llama-3.1-70b-instruct
```

---

## 🔮 Mistral (Via OpenRouter)

```
openrouter/mistralai/mistral-small-2603
openrouter/mistralai/mistral-large-2512
openrouter/mistralai/devstral-2512        ← Coding
openrouter/mistralai/codestral-2508       ← Coding
openrouter/mistralai/mistral-medium-3
openrouter/mistralai/ministral-8b-2512
openrouter/mistralai/mistral-small-3.1-24b-instruct:free
```

---

## 🌙 Moonshot / Kimi (Via OpenRouter)

```
openrouter/moonshotai/kimi-k2.5
openrouter/moonshotai/kimi-k2-thinking
openrouter/moonshotai/kimi-k2
```

---

## 🤖 X-AI / Grok (Via OpenRouter)

```
openrouter/x-ai/grok-4
openrouter/x-ai/grok-4.20-beta
openrouter/x-ai/grok-4.1-fast
openrouter/x-ai/grok-3
openrouter/x-ai/grok-3-mini
```

---

## 🌐 Lainnya (Via OpenRouter)

```
# ByteDance Seed
openrouter/bytedance-seed/seed-2.0-lite
openrouter/bytedance-seed/seed-1.6

# Amazon Nova
openrouter/amazon/nova-premier-v1
openrouter/amazon/nova-pro-v1
openrouter/amazon/nova-lite-v1

# Nvidia Nemotron
openrouter/nvidia/nemotron-3-super-120b-a12b
openrouter/nvidia/nemotron-3-super-120b-a12b:free

# Cohere
openrouter/cohere/command-a
openrouter/cohere/command-r-plus-08-2024

# Microsoft
openrouter/microsoft/phi-4

# Liquid
openrouter/liquid/lfm-2-24b-a2b

# Perplexity
openrouter/perplexity/sonar-pro-search     ← Dengan web search
```

---

## 📋 Cara Tambah Model Baru ke Agent

Edit `/root/.openclaw/openclaw.json` → `agents.list.agentN.model`:

```json
{
  "id": "agent1",
  "model": {
    "primary": "openrouter/z-ai/glm-5-turbo",
    "fallbacks": [
      "openrouter/google/gemini-2.5-flash",
      "deepseek/deepseek-chat"
    ]
  }
}
```

Restart gateway setelah edit:
```bash
kill -TERM $(pgrep -f openclaw-gateway) && sleep 3
```
