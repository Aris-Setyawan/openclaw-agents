# TOOLS.md — Shared Tool Notes

---

## ⚠️ Model Limitations — WAJIB BACA

### Google Gemini (via proxy) — TIDAK SUPPORT TOOLS/SKILLS
Model Google Gemini (`models/gemini-*`) yang jalan via proxy `127.0.0.1:9998` **TIDAK bisa menjalankan skill/tool/function calling**. Kalau dipaksa → **ERROR**.

Gemini hanya bisa: text generation, image understanding (input), reasoning.
**TIDAK BISA:** exec commands, read/write files, web search, atau tool calls.

⚠️ **Ini khusus Gemini via proxy saja.** Model lain (DeepSeek, Qwen, dll) tetap bisa pakai tools/skills meski kadang kurang reliable.

### Tool Support Per Provider
| Provider | Models | Tools | Notes |
|----------|--------|-------|-------|
| Anthropic | Claude Opus/Sonnet/Haiku 4.x+ | ✅ Full | Paling reliable |
| OpenAI | GPT-4o/5.x | ✅ Full | Via OpenRouter |
| DeepSeek | V3, R1 | ✅ Works | Kadang skip, tapi mostly OK |
| Qwen | qwen3.x | ✅ Works | Kadang format salah |
| Google Gemini | gemini-* (via proxy) | ❌ ERROR | Jangan assign tool tasks! |

---

## 🤖 Agent Setup

| Agent | Model | Role | Backup | Tools? |
|-------|-------|------|--------|--------|
| main | claude-opus-4-5 | TUI/main | — | ✅ |
| agent1 | claude-opus-4-6 | Telegram handler (Santa) | agent5 | ✅ |
| agent2 | deepseek-chat | Creative/Content | agent6 | ⚠️ |
| agent3 | deepseek-reasoner | Analytical/Research | agent7 | ⚠️ |
| agent4 | claude-opus-4-6 | Technical/Coding | agent8 | ✅ |
| agent5 | claude-haiku-4-5 | Backup agent1 | — | ✅ |
| agent6 | qwen3.5-plus | Backup agent2 | — | ⚠️ |
| agent7 | qwen3-max | Backup agent3 | — | ⚠️ |
| agent8 | qwen3-coder-next | Coder/Backup agent4 | — | ⚠️ |

**Routing Rule:**
- Kreatif/konten → agent2 (DeepSeek V3)
- Analisa/riset → agent3 (DeepSeek R1)
- Coding/teknis → agent4 (Claude Opus)
- Jika primary down → backup pair (5/6/7/8)

---

## 🔑 Credentials

| Provider | Location | Key Path |
|----------|----------|----------|
| Anthropic | `auth-profiles.json` | `.profiles."anthropic:default".token` |
| OpenAI | `auth-profiles.json` | `.profiles."openai:default".token` |
| DeepSeek | `models.json` | `.providers.deepseek.apiKey` |
| OpenRouter | `auth-profiles.json` | `.profiles."openrouter:default".key` |
| ModelStudio | `models.json` | `.providers.modelstudio.apiKey` |
| Gemini | `models.json` | `.providers.google.headers.Authorization` |

**Base path:** `~/.openclaw/agents/main/agent/`

---

## 🎙️ Text-to-Speech (TTS)

### Default: OpenAI TTS
```bash
/root/.openclaw/workspace/scripts/openai-tts.sh "Teks..." --send
# Voice: nova | Model: tts-1 | Speed: 1.0
# Pakai ellipsis (...) untuk jeda natural
# Cost: ~Rp 2.3 per 1000 karakter
```
**Voices:** alloy, echo, fable, onyx, **nova** (default), shimmer
**Options:** `--voice NAME` `--model tts-1-hd` `--speed 0.5-4.0` `--send`

### Fallback 1: Gemini TTS (Gratis)
```bash
/root/.openclaw/workspace/scripts/gemini-tts.sh "Teks..." --send
# Voice: Kore | Model: gemini-2.5-flash-preview-tts
# 30 voices: Kore, Aoede, Puck, Charon, Zephyr, dll
```

### Fallback 2: Edge TTS (Gratis, Unlimited)
```bash
/root/.openclaw/workspace/scripts/edge-tts.sh "Teks..." --send
# Voice: id-ID-GadisNeural (ID) / en-US-JennyNeural (EN)
# 300+ voices, auto-detect bahasa
```

**Prioritas TTS:** OpenAI Nova → Gemini Kore → Edge TTS

---

## 🖼️ Image Generation

### ⚠️ ATURAN WAJIB
1. **PANGGIL SCRIPT LANGSUNG** — jangan delegate ke agent lain
2. **Default style: SELALU photorealistic** kecuali user eksplisit minta anime/kartun
3. **WAJIB KONFIRMASI** dulu sebelum generate (biaya Rp 1-20K per gambar)

### Cara Generate
```bash
/root/.openclaw/workspace/scripts/generate-image.sh "[deskripsi], photorealistic, professional photography, natural lighting, 4K" "[caption]"
```
Script otomatis: model picker Telegram → generate → kirim. Output `IMAGE_SENT_OK` = selesai.

---

## 🎬 Video Generation

### ⚠️ MAHAL — SELALU KONFIRMASI
```bash
/root/.openclaw/workspace/scripts/generate-video.sh "[prompt]" "[caption]"
```
**Cost:** Rp 10,000 - Rp 15,000 per video. WAJIB tanya user dulu!

---

## 📤 Kirim File ke Telegram

```bash
/root/.openclaw/workspace/scripts/telegram-send.sh <file_path> [caption]
```
**PENTING:** Setiap generate/download gambar/audio/video → LANGSUNG kirim pakai script ini.

---

## 🖥️ Desktop / VNC Control

### Deteksi Intent — LANGSUNG jalankan
**Enable:** "buka android studio", "nyalain vnc", "mau remote desktop"
**Disable:** "matiin desktop", "tutup vnc", "hemat ram"

```bash
desktop.sh enable    # hidupkan VNC + XFCE
desktop.sh disable   # matikan (hemat ~100MB RAM)
desktop.sh status    # cek kondisi
```
**Auto-watchdog** aktif — matikan otomatis setelah 30 menit tanpa koneksi.

---

## 📜 All Scripts Reference

### Communication
| Script | Fungsi |
|--------|--------|
| `telegram-send.sh` | Kirim file/gambar ke Telegram |
| `telegram-model-picker.sh` | Inline keyboard model picker |

### Generation
| Script | Fungsi | Cost |
|--------|--------|------|
| `openai-tts.sh` | TTS OpenAI (default) | ~Rp 2.3/1K char |
| `gemini-tts.sh` | TTS Gemini (fallback) | Gratis |
| `edge-tts.sh` | TTS Edge (fallback) | Gratis |
| `generate-audio.sh` | Legacy TTS wrapper | Varies |
| `generate-image.sh` | Image generation + picker | Rp 1-20K |
| `generate-image-direct.sh` | Image gen tanpa picker | Rp 1-20K |
| `generate-video.sh` | Video generation + picker | Rp 10-15K |
| `generate-video-direct.sh` | Video gen tanpa picker | Rp 10-15K |

### Monitoring & Maintenance
| Script | Fungsi |
|--------|--------|
| `check-all-balances.sh` | Cek saldo semua API provider |
| `check-api-health.sh` | Detect loops, rate spikes, errors |
| `monitor-fallback.sh` | Monitor model fallback antar agent |
| `monitor-model-usage.sh` | Monitor API usage & detect spikes |
| `log-model-fallback.sh` | Log fallback events |
| `monitor-api-usage.sh` | Track image/video generation |
| `clear-agent-sessions.sh` | Clear old sessions (cron tiap 3 hari) |
| `watch-ssh-bruteforce.sh` | Monitor SSH brute force attempts |
| `check-disk-remote.sh` | Audit disk remote server |

### Delegation & Confirmation
| Script | Fungsi |
|--------|--------|
| `delegate-with-report.sh` | Delegate task + auto-report saat selesai |
| `confirm-action.sh` | Interactive confirmation prompt |
| `request-confirmation.sh` | Request confirmation via Telegram |
| `check-user-approval.sh` | Check if user approved action |

### Utilities
| Script | Fungsi |
|--------|--------|
| `send-weather.sh` | Kirim cuaca ke Telegram (cron daily) |
| `openrouter-calculator.sh` | Hitung cost dari session usage |
| `test-multi-agent.sh` | Test integrasi multi-agent |

---

## 🔄 Multi-Agent Delegation

```bash
OPENCLAW=/www/server/nvm/versions/node/v22.20.0/bin/openclaw

# Delegate ke agent tertentu
$OPENCLAW agent --agent agent2 --message "Buat tagline produk X"
$OPENCLAW agent --agent agent3 --message "Analisa data ini: ..."
$OPENCLAW agent --agent agent4 --message "Fix bug ini: ..."

# Dengan auto-report
/root/.openclaw/workspace/scripts/delegate-with-report.sh agent2 "Buat tagline" "✅ Tagline selesai!"
```

**SELALU kasih update ke user begitu task selesai** — jangan diam!

---

## ⚡ Quick Commands

```bash
# Gateway
openclaw status                    # Status lengkap
openclaw gateway restart           # Restart gateway

# Sessions
rm -f ~/.openclaw/agents/agent1/sessions/*.jsonl   # Clear sessions

# Balances
/root/.openclaw/workspace/scripts/check-all-balances.sh

# Health
cat /root/.openclaw/workspace/health-state.json | python3 -m json.tool
```

---

## 💰 Cost Reference

| Service | Cost | Notes |
|---------|------|-------|
| Anthropic (Claude) | Unlimited plan | No per-token cost |
| DeepSeek | ~$0 (very cheap) | Deposit based |
| Gemini | Free tier | Rate limited |
| OpenRouter | Per-token | Check model pricing |
| OpenAI TTS | ~$0.015/1K chars | ~Rp 2.3/1K chars |
| Image Gen | Rp 1,000-20,000 | Per image |
| Video Gen | Rp 10,000-15,000 | Per video |

---

## 🔄 Workflow Automation

| Workflow | Schedule | Function |
|----------|----------|----------|
| `morning-briefing.sh` | Daily 7:00 AM WIB | Cuaca, system status, API balances, disk space |
| `auto-git-commit.sh` | Every 6 hours | Auto-commit workspace changes to git |
| `health-check.sh` | Every 2 hours | Agent health, disk, memory, sessions |

**Location:** `/root/.openclaw/workspace/workflows/`

**Manual run:**
```bash
/root/.openclaw/workspace/workflows/morning-briefing.sh
/root/.openclaw/workspace/workflows/auto-git-commit.sh
/root/.openclaw/workspace/workflows/health-check.sh
```

**Logs:** `/tmp/*.log` (morning-briefing.log, auto-git-commit.log, health-check.log)

---

## 🛠️ Available Skills

| Skill | Description | Use When |
|-------|-------------|----------|
| `auto-report` | Auto-reporting setelah delegasi task | Delegate ke agent lain |
| `confirm-before-action` | Konfirmasi sebelum aksi mahal/risiko | Image/video gen, deletion |
| `github` | GitHub operations via `gh` CLI | Issues, PRs, CI, code review |
| `weather` | Get weather & forecasts | User asks about weather |
| `nano-pdf` | PDF processing & analysis | Read/extract PDF content |
| `openai-image-gen` | Generate images via DALL-E | Image generation requests |
| `summarize` | Summarize text/content | Long text, articles, docs |
| `tmux` | Remote-control tmux sessions | Interactive CLI control |
| `video-frames` | Extract frames from videos | Video analysis |
| `xurl` | URL shortener/expander | Link management |

**Pre-installed skills** (available globally): `coding-agent`, `gh-issues`, `gemini`, `healthcheck`, `node-connect`, `skill-creator`, `nano-banana-pro`, `openai-whisper`, `sag`, `session-logs`, `sherpa-onnx-tts`, `spotify-player`, `trello`, `voice-call`, `wacli`, dan 40+ lainnya.

---

## 📝 Important Notes

- Credentials di `auth-profiles.json` dan `models.json`, BUKAN env vars
- Pakai script yang sudah ada sebelum bikin baru
- Workspace shared: `/root/.openclaw/workspace`
- Backup lokasi: `/root/openclaw-backup-YYYYMMDD-HHMMSS/`
- **Google Gemini TIDAK support tools/skills** — jangan assign tool-based tasks
- **SELALU konfirmasi** sebelum generate image/video (biaya!)
- **SELALU kirim file** ke Telegram setelah generate (jangan tunggu diminta)
- **Skill path:** `/root/.openclaw/workspace/skills/<name>/SKILL.md`
