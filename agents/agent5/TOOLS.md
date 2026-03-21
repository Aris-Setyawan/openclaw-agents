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

Gunakan command ini untuk delegate task ke agent lain via bash:
```bash
# Kirimi agent lain task dan dapat response
OPENCLAW=/www/server/nvm/versions/node/v22.20.0/bin/openclaw

# Delegate ke agent tertentu
$OPENCLAW agent --agent agent2 --message "Buat tagline produk X"
$OPENCLAW agent --agent agent3 --message "Analisa data ini: ..."
$OPENCLAW agent --agent agent4 --message "Fix bug ini: ..."

# Contoh pakai di bash:
result=$($OPENCLAW agent --agent agent3 --message "Analisa: ..." 2>/dev/null)
echo "agent3 jawab: $result"
```

**Routing Rule:**
- Kreatif/konten → agent2 (DeepSeek)
- Analisa/riset → agent3 (DeepSeek Reasoner)
- Coding/teknis → agent4 (Claude Opus)
- Jika primary down → coba agent 5/6/7/8 (backup pair)

## Image Generation

### Primary: Gemini Image Gen (GRATIS) 🍌
```bash
export GEMINI_API_KEY=<dari auth-profiles.json gemini:default>
export PATH="$HOME/.local/bin:$PATH"
SKILL=/www/server/nvm/versions/node/v22.20.0/lib/node_modules/openclaw/skills/nano-banana-pro
uv run $SKILL/scripts/generate_image.py --prompt "deskripsi gambar" --filename "/tmp/output.png" --resolution 1K

# Setelah generate, kirim ke Telegram:
/root/.openclaw/workspace/scripts/telegram-send.sh /tmp/output.png "Caption gambar"
```

### Fallback: DALL-E 3 (berbayar, pakai OpenAI key)
```bash
SKILL=/www/server/nvm/versions/node/v22.20.0/lib/node_modules/openclaw/skills/openai-image-gen
python3 $SKILL/scripts/gen.py --prompt "deskripsi" --model dall-e-3 --count 1 --out-dir /tmp/imgout
```
