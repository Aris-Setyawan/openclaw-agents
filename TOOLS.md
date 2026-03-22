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

# Cek API health & detect loops (NEW!)
/root/.openclaw/workspace/scripts/check-api-health.sh 24  # last 24 hours
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

## API Usage Monitoring & Cost Control 🔒

### Monitoring Tools (implementasi Mar 22, 2026)

**1. Real-time monitoring:**
```bash
/root/.openclaw/workspace/scripts/check-api-health.sh [hours]
# Contoh: /root/.openclaw/workspace/scripts/check-api-health.sh 24
```

**2. Manual log check:**
```bash
tail -f /root/.openclaw/workspace/logs/api-usage.log
```

**3. Detect rate spikes:**
- Script otomatis log setiap image/video request
- Warning jika >5 requests dalam 1 menit
- Alert tersimpan di log dengan tag `ALERT`

### Cost Protection Rules

1. **SELALU pakai direct mode** untuk image/video gen (bypass agent context)
2. **JANGAN retry** otomatis tanpa confirm user
3. **Veo 3 Fast ONLY** kecuali diminta quality tinggi
4. **Monitor daily** - check api-health setiap pagi
5. **Limit: Max 10 images + 3 videos per hari** (self-imposed)

### Troubleshooting High Cost

Jika billing tiba-tiba tinggi:
1. `check-api-health.sh 48` → cari spike/alerts
2. Check for loops: `grep ALERT logs/api-usage.log`
3. Audit Cloud Console billing breakdown
4. Disable auto-retry di scripts kalau perlu

## Important Notes
- Credentials di `auth-profiles.json`, BUKAN environment variables
- Pakai script yang sudah ada sebelum bikin baru
- Workspace shared: `/root/.openclaw/workspace`
- **NEW:** Semua API calls di-log untuk cost tracking

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

## Image Generation ⭐ INI TUGAS AGENT 2

Agent1 akan delegate generate gambar ke sini. Kamu yang eksekusi.

### ⚠️ ATURAN WAJIB
1. **Default: SELALU photorealistic** kecuali diminta anime/kartun/ilustrasi
2. Wajib tambahkan ke prompt: `photorealistic, professional photography, natural lighting, 4K, lifelike`
3. Coba **Gemini dulu** → DALL-E hanya fallback kalau Gemini gagal
4. **MONITORING AKTIF** - setiap request dicatat untuk detect loops/abuse

### Generate + Kirim Telegram — CUKUP SATU COMMAND:
```bash
/root/.openclaw/workspace/scripts/generate-image.sh "[deskripsi], photorealistic, professional photography, natural lighting, 4K, lifelike" "[caption]"
```
Script otomatis handle: API key → Gemini → fallback DALL-E → kirim Telegram → log usage.
> ❌ Output script `IMAGE_SENT_OK` — **JANGAN kirim file lagi**, sudah terkirim otomatis.

### Direct Mode (bypass agent context overhead):
```bash
# Untuk hindari context bloat (MEMORY.md, AGENTS.md, dll)
/root/.openclaw/workspace/scripts/generate-image-direct.sh "[prompt]" "[caption]"
```

### Fallback: DALL-E 3 (hanya jika Gemini gagal / rate limit)
```bash
SKILL=/www/server/nvm/versions/node/v22.20.0/lib/node_modules/openclaw/skills/openai-image-gen
OUT_DIR=/tmp/imgout-$(date +%s)
python3 $SKILL/scripts/gen.py --prompt "[deskripsi]" --model dall-e-3 --count 1 --out-dir $OUT_DIR
ls $OUT_DIR/*.png | head -1  # balas dengan path file
```
> Jika DALL-E kena content filter → tetap pakai Gemini, jangan retry DALL-E

## Video Generation ⭐ INI JUGA TUGAS AGENT 2

Agent1 delegate video gen ke sini via bash. Kamu yang eksekusi.

### Generate Video + Kirim Telegram — CUKUP SATU COMMAND:
```bash
/root/.openclaw/workspace/scripts/generate-video.sh "[deskripsi video]" "[caption]" [provider] [durasi 5-8]
```

**Contoh:**
```bash
# Default (kie.ai Veo3 Fast, 6 detik, HEMAT!)
/root/.openclaw/workspace/scripts/generate-video.sh "wanita tersenyum di taman, sinematik, 4K" "Video Wulan 🎬"

# Explicit kie.ai (sama dengan default)
/root/.openclaw/workspace/scripts/generate-video.sh "prompt" "caption" "kieai" 6

# Google Veo (MAHAL! ~Rp 20K/video)
/root/.openclaw/workspace/scripts/generate-video.sh "prompt" "caption" "google" 8
```

### Direct Mode (bypass agent context overhead):
```bash
# Untuk hindari context bloat (MEMORY.md, AGENTS.md, dll)
/root/.openclaw/workspace/scripts/generate-video-direct.sh "[prompt]" "[caption]" [provider] [durasi]
```

**Provider Comparison:**
| Provider | Cost | Speed | Quality | Audio Charge |
|----------|------|-------|---------|--------------|
| `kieai` (default) | ~Rp 10-15K | 1-2 min | Good | ✅ Included |
| `google` | ~Rp 18-23K | 1-3 min | Better | ❌ Separate (~Rp 15K) |

> Script otomatis: ambil API key → submit ke Veo → poll sampai selesai → download → kirim Telegram → log usage
> ❌ Output script `VIDEO_SENT_OK` — **JANGAN kirim file lagi**, sudah terkirim otomatis.
> Video generation butuh waktu 1-3 menit — kasih tau user untuk tunggu

### ⚠️ COST AWARENESS & HEMAT
🚨 **DEFAULT CHANGED (Mar 22, 2026):** Script sekarang pakai **kie.ai** sebagai primary!

**Why?**
- Google Veo charge VIDEO + AUDIO TERPISAH (~Rp 18-23K total/video) 😱
- kie.ai Veo3 Fast: flat rate ~Rp 10-15K (audio included) ✅
- Hemat ~40-50% per video!

**Cost Comparison:**
| Provider | Video | Audio | Total |
|----------|-------|-------|-------|
| kie.ai Veo3 Fast | Rp 10-15K | ✅ Included | **Rp 10-15K** |
| Google Veo 3 Fast | Rp 3-8K | ❌ Rp 15K | **Rp 18-23K** |
| Google Veo 3 Standard | Rp 20-30K | ❌ Rp 15K | **Rp 35-45K** |

**Daily Limits (Updated):**
- Images: Max 10/hari
- Videos (kie.ai): Max 5/hari (hemat!)
- Videos (Google): Max 2/hari (mahal!)

**Recommendations:**
- ✅ Pakai default (kie.ai) untuk semua video
- ❌ Avoid Google Veo kecuali butuh quality premium
- Jangan retry otomatis tanpa confirm

## Audio / TTS ⭐ INI JUGA TUGAS AGENT 2

### Generate Suara + Kirim Telegram — SATU COMMAND:
```bash
/root/.openclaw/workspace/scripts/generate-audio.sh "[teks yang dibacakan]" "[caption]" "[voice]"
```

**Voice Google (primary):** `Aoede` (wanita lembut), `Kore` (wanita tegas), `Charon` (pria), `Fenrir` (pria dalam), `Puck` (ceria)
**Voice OpenAI (fallback):** `nova`, `alloy`, `echo`, `fable`, `onyx`, `shimmer`

**Contoh:**
```bash
/root/.openclaw/workspace/scripts/generate-audio.sh "Selamat pagi mas Aris!" "Pesan suara 🎙️" "Aoede"
```

> ❌ Output script `AUDIO_SENT_OK` — **JANGAN kirim file lagi**, sudah terkirim otomatis.
> Primary: Google Gemini TTS → Fallback: OpenAI TTS
