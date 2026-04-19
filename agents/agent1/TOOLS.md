# TOOLS.md — Shared Tool Notes

## Scripts yang Tersedia

### Kirim File/Gambar ke Telegram ⚠️ WAJIB setelah generate gambar
```bash
/root/.openclaw/workspace/scripts/telegram-send.sh <file_path> [caption]
# Contoh:
/root/.openclaw/workspace/scripts/telegram-send.sh /path/to/image.png "Caption gambar"
```
**PENTING:** Setiap kali generate/download gambar, LANGSUNG kirim ke Telegram pakai script ini. Jangan tunggu user minta.

### Check All API Balances
```bash
/root/.openclaw/workspace/scripts/check-all-balances.sh
```

## Credential Locations

| Provider | File | Key Path |
|----------|------|----------|
| DeepSeek | `~/.openclaw/agents/main/agent/auth-profiles.json` | `.profiles."deepseek:default".token` |
| OpenRouter | `~/.openclaw/agents/main/agent/auth-profiles.json` | `.profiles."openrouter:default".key` |
| Anthropic | `~/.openclaw/agents/main/agent/auth-profiles.json` | `.profiles."anthropic:default".token` |
| ModelStudio | `~/.openclaw/agents/main/agent/models.json` | `.providers.modelstudio.apiKey` |

## Quick Commands

```bash
# Cek gateway status
openclaw status

# Cek semua agent & model
openclaw config get agents.list | jq -r '.[] | "\(.id): \(.model // "default")"'

# Restart gateway
pkill -9 -f openclaw-gateway && sleep 3

# Clear session agent tertentu
rm -f ~/.openclaw/agents/agent1/sessions/*.jsonl

# Cek saldo API
/root/.openclaw/workspace/scripts/check-all-balances.sh
```

## Agent Setup

| Agent | Model | Role |
|-------|-------|------|
| main | claude-opus-4-5 | TUI/main |
| agent1 | claude-sonnet-4-6 | Telegram (switched from Haiku, unlimited Anthropic) |
| agent2 | deepseek-chat | Creative |
| agent3 | deepseek-reasoner | Analytical |
| agent4 | claude-opus-4-6 | Technical |
| agent5 | claude-haiku-4-5 | Backup |
| agent6 | qwen3.5-plus | Backup |
| agent7 | qwen3-max | Backup |
| agent8 | qwen3-coder-next | Coder |

## Important Notes
- Credentials di `auth-profiles.json`, BUKAN environment variables
- Pakai script yang sudah ada sebelum bikin baru
- Workspace shared: `/root/.openclaw/workspace`

## Multi-Agent Delegation (PENTING!)

**SELALU gunakan tool `sessions_spawn`** — JANGAN pakai bash CLI untuk delegate.

### Cara Delegate:
```
sessions_spawn:
  task: "deskripsi lengkap task"
  agentId: "agent2"       # target agent
  mode: "run"             # one-shot, selesai otomatis
  label: "nama-task"      # label singkat
```

### Routing Rule:
- Kreatif/konten → agent2 (DeepSeek)
- Analisa/riset → agent3 (DeepSeek Reasoner)
- Coding/teknis → agent4 (Claude Opus)
- Jika primary down → coba agent 5/6/7/8 (backup pair)

### Setelah Spawn:
- Gateway akan push completion event ke kamu secara otomatis
- JANGAN polling (sessions_list, sessions_history, exec sleep)
- Tunggu completion event → presentasikan hasilnya ke user
- User bisa ketik /stop untuk batalkan

## Image Generation

### ⚠️ ATURAN WAJIB IMAGE GEN
1. **PANGGIL SCRIPT LANGSUNG** — jangan delegate ke agent2 (boros token context agent2)
2. **Default style: SELALU photorealistic** kecuali user eksplisit minta anime/kartun

### Cara Generate — CUKUP SATU COMMAND:
```bash
/root/.openclaw/workspace/scripts/generate-image.sh "[deskripsi], photorealistic, professional photography, natural lighting, 4K" "[caption]"
```
Script otomatis: model picker Telegram → generate → kirim. Output `IMAGE_SENT_OK` = selesai.
