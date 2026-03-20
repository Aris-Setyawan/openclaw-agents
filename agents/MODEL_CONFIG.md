# Model Configuration per Agent

> Last updated: 2026-03-20
> Strategy: Google direct API via OpenAI-compat endpoint `/v1beta/openai` untuk agent1 (no markup), OpenRouter selalu last fallback

## Catatan Google Direct API
Google Gemini via OpenAI-compatible endpoint (`/v1beta/openai/chat/completions`):
- ✅ Mendukung `max_tokens` (OpenAI standard) — tidak perlu `max_completion_tokens`
- ✅ `gemini-2.5-flash` bekerja via endpoint ini dengan `Authorization: Bearer API_KEY`
- ❌ `gemini-3-flash-preview` tidak stabil / unavailable di direct API — pakai OpenRouter
- **Provider config:** `baseUrl: https://generativelanguage.googleapis.com/v1beta/openai`

## Routing Logic
- **Chat / Q&A / Analisis file** → agent1 (Gemini 2.5 Flash direct, no markup)
- **Generate teks panjang >500 kata / laporan / artikel** → agent2 (DeepSeek, output murah)
- **Reasoning / Research** → agent3 (DeepSeek Reasoner)
- **Coding / DevOps** → agent4 (Claude Opus)

## Agent Models

| Agent | Role | Primary | Fallback 1 | Fallback 2 | Fallback 3 |
|-------|------|---------|------------|------------|------------|
| agent1 | Orchestrator / Chat | `gemini/models/gemini-2.5-flash` | `deepseek/deepseek-chat` | `modelstudio/qwen3.5-plus` | `openrouter/google/gemini-2.5-flash` |
| agent2 | Creative / Long-form | `deepseek/deepseek-chat` | `modelstudio/qwen3.5-plus` | `anthropic/claude-haiku-4-5` | `openrouter/google/gemini-2.5-flash` |
| agent3 | Analytical / Reasoning | `deepseek/deepseek-reasoner` | `modelstudio/qwen3-max` | `deepseek/deepseek-chat` | `openrouter/google/gemini-2.5-flash` |
| agent4 | Technical / Coding | `anthropic/claude-opus-4-6` | `anthropic/claude-haiku-4-5` | `modelstudio/qwen3-coder-next` | `deepseek/deepseek-chat` |
| agent5 | Backup Orchestrator | `anthropic/claude-haiku-4-5` | `modelstudio/qwen3.5-plus` | `deepseek/deepseek-chat` | `openrouter/google/gemini-2.5-flash` |
| agent6 | Backup Creative | `modelstudio/qwen3.5-plus` | `deepseek/deepseek-chat` | `anthropic/claude-haiku-4-5` | `openrouter/google/gemini-2.5-flash` |
| agent7 | Backup Analytical | `modelstudio/qwen3-max` | `deepseek/deepseek-reasoner` | `modelstudio/qwen3.5-plus` | `openrouter/google/gemini-2.5-flash` |
| agent8 | Backup Technical | `modelstudio/qwen3-coder-next` | `modelstudio/qwen3-coder-plus` | `deepseek/deepseek-chat` | `anthropic/claude-haiku-4-5` |

## Cost Strategy

| Provider | Keunggulan | Kapan Dipakai |
|----------|-----------|---------------|
| Google Direct (`/v1beta/openai`) | No markup, supports max_tokens, gemini-2.5-flash OK | Primary agent1 |
| DeepSeek Chat | Output 2.8x lebih murah | Primary agent2, generate panjang |
| ModelStudio (Qwen) | Murah, fallback menengah | Fallback agent lain |
| Anthropic Claude | Kualitas tinggi | Agent4 primary, coding |
| OpenRouter | Last resort semua agent | Fallback universal |

## API Keys (berbeda per server)
- `GOOGLE_API_KEY` — Google direct via `/v1beta/openai` (primary agent1, no OpenRouter markup)
- `DEEPSEEK_API_KEY` — DeepSeek direct
- `DASHSCOPE_API_KEY` — ModelStudio/Qwen
- `ANTHROPIC_API_KEY` — Claude
- `OPENROUTER_API_KEY` — Primary Gemini + fallback universal
