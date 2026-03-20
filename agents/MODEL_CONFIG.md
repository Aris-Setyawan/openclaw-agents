# Model Configuration per Agent

> Last updated: 2026-03-20
> Strategy: Direct API (no markup) as primary, OpenRouter selalu last fallback

## Routing Logic
- **Chat / Q&A / Analisis file** → agent1 (Gemini, input murah)
- **Generate teks panjang >500 kata / laporan / artikel** → agent2 (DeepSeek, output murah)
- **Reasoning / Research** → agent3 (DeepSeek Reasoner)
- **Coding / DevOps** → agent4 (Claude Opus)

## Agent Models

| Agent | Role | Primary | Fallback 1 | Fallback 2 | Fallback 3 |
|-------|------|---------|------------|------------|------------|
| agent1 | Orchestrator / Chat | `google/gemini-2.5-flash` | `deepseek/deepseek-chat` | `modelstudio/qwen3.5-plus` | `openrouter/google/gemini-2.5-flash` |
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
| Google Gemini Direct | Input 10x lebih murah dari OpenRouter | Primary agent1, chat & analisis file |
| DeepSeek Chat | Output 2.8x lebih murah | Primary agent2, generate teks panjang |
| ModelStudio (Qwen) | Gratis / murah | Fallback menengah |
| Anthropic Claude | Kualitas tinggi | Agent4 primary, coding & task kompleks |
| OpenRouter | Universal fallback | Last resort semua agent (markup 10-20%) |

## API Keys
- `GOOGLE_API_KEY` — Gemini direct (paid tier, per server)
- `DEEPSEEK_API_KEY` — DeepSeek direct
- `DASHSCOPE_API_KEY` — ModelStudio/Qwen
- `ANTHROPIC_API_KEY` — Claude
- `OPENROUTER_API_KEY` — Fallback universal
