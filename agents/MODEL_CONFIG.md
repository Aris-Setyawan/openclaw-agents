# Model Configuration per Agent

> Last updated: 2026-03-21
> Strategy: Google direct API via transparent proxy (port 9998) — strip params yang tidak didukung

## Google Direct API via Proxy (SOLVED)
OpenClaw mengirim parameter non-standard yang ditolak Google:
- `store` → `Unknown name "store": Cannot find field`
- `thinking` / `thinking_effort` → tidak dikenal Google OpenAI-compat endpoint
- `max_completion_tokens` → harus di-rename ke `max_tokens`

**Solusi:** `google-proxy.py` di port 9998 (systemd: `openclaw-google-proxy`)
- Strip: `store`, `user`, `thinking`, `thinking_effort`
- Rename: `max_completion_tokens` → `max_tokens`
- Forward ke: `https://generativelanguage.googleapis.com/v1beta/openai`

**Syarat model config:**
- `reasoning: true` harus di-set untuk model yang mau terima thinking requests
- Tanpa ini, OpenClaw skip provider saat thinking mode aktif → fallback ke Haiku

## Routing Logic
- **Chat / Q&A / Analisis file** → agent1 (Gemini 2.5 Flash direct, no markup)
- **Generate teks panjang >500 kata / laporan / artikel** → agent2 (DeepSeek, output murah)
- **Reasoning / Research** → agent3 (DeepSeek Reasoner)
- **Coding / DevOps** → agent4 (Claude Opus)

## Agent Models

| Agent | Role | Primary | Fallback 1 | Fallback 2 | Fallback 3 |
|-------|------|---------|------------|------------|------------|
| agent1 | Orchestrator / Chat | `openrouter/google/gemini-2.5-flash` | `deepseek/deepseek-chat` | `modelstudio/qwen3.5-plus` | `openrouter/google/gemini-2.0-flash` |
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
| OpenRouter Gemini | Strip param non-standard, handle API compat, reliable | Primary agent1 |
| DeepSeek Chat | Output 2.8x lebih murah | Primary agent2, generate panjang |
| ModelStudio (Qwen) | Murah, fallback menengah | Fallback agent lain |
| Anthropic Claude | Kualitas tinggi | Agent4 primary, coding |
| OpenRouter | Last resort semua agent | Fallback universal |

## API Keys (berbeda per server)
- `GOOGLE_API_KEY` — Tidak digunakan (Google direct API tidak kompatibel dengan OpenClaw)
- `DEEPSEEK_API_KEY` — DeepSeek direct
- `DASHSCOPE_API_KEY` — ModelStudio/Qwen
- `ANTHROPIC_API_KEY` — Claude
- `OPENROUTER_API_KEY` — Primary Gemini + fallback universal
