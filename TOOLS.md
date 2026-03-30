# TOOLS.md — Shared Tool Notes

## Desktop / VNC Control (Android Studio)

### ⚠️ ATURAN WAJIB — Deteksi Intent Android Studio
Perhatikan kalimat user dengan seksama:

**LANGSUNG jalankan `desktop.sh enable`** jika user bilang sesuatu seperti:
- "mau pakai android studio", "buka android studio", "nyalain android studio"
- "mau coding android", "mau develop app", "hidupkan desktop", "nyalain vnc"
- "mau remote desktop", "mau buka vnc", "enable desktop"

**LANGSUNG jalankan `desktop.sh disable`** jika user bilang:
- "matiin android studio", "tutup desktop", "disable vnc", "matiin layar"
- "udah selesai android studio", "gak pakai android studio lagi", "disable desktop"
- "hemat ram", "nonaktifin vnc", "turn off desktop"

```bash
desktop.sh enable    # hidupkan VNC + XFCE (sebelum Android Studio)
desktop.sh disable   # matikan VNC + XFCE (hemat ~100MB RAM)
desktop.sh status    # cek kondisi sekarang
```

Setelah enable, balas user dengan:
> "Desktop aktif! Buka VNC viewer ke `[IP]:5901` atau browser ke `http://[IP]:6080`"

Setelah disable, balas:
> "Desktop dimatikan, RAM dibebaskan."

**Auto-watchdog** sudah aktif — otomatis matikan desktop setelah 30 menit tidak ada koneksi VNC.

---

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
# Cek gateway status (PAKAI INI, bukan `openclaw status`!)
openclaw gateway status

# Cek semua agent & model (real-time dari openclaw.json)
openclaw config get agents.list | jq -r '.[] | "\(.id): \(.model.primary // "global")"'

# Cek global default
openclaw config get agents.defaults.model

# Restart gateway
openclaw gateway restart

# Clear session agent tertentu
rm -f ~/.openclaw/agents/agent1/sessions/*.jsonl

# Cek saldo API
/root/.openclaw/workspace/scripts/check-all-balances.sh
```

## ⚠️ Gateway Status — JANGAN SALAH BACA!

**`openclaw status`** sering menampilkan `unreachable (missing scope: operator.read)` — ini **NORMAL** untuk gateway yang bind ke loopback (127.0.0.1). Ini BUKAN error, BUKAN masalah permission, BUKAN berarti gateway down.

**Cara BENAR cek gateway:**
```bash
openclaw gateway status    # ← PAKAI INI! Tampilkan PID, state, RPC probe
```

**JANGAN:**
- ❌ Panik kalau lihat "missing scope: operator.read"
- ❌ Coba restart gateway karena pesan ini
- ❌ Coba tambah operator config / permission
- ❌ Laporkan ke user bahwa gateway unreachable

**LAKUKAN:**
- ✅ Pakai `openclaw gateway status` untuk cek status sebenarnya
- ✅ Kalau `state: active` dan `rpc probe: ok` → gateway JALAN NORMAL
- ✅ Kalau ada masalah koneksi sungguhan → cek `cat /tmp/pawang.log` atau gateway log

## Ganti Model Agent — ATURAN WAJIB

### ⚠️ DILARANG KERAS:
```bash
# JANGAN PERNAH PAKAI INI — mengubah SEMUA agent sekaligus!
openclaw config set agents.defaults.model.primary "..."     # ← SALAH! INI GLOBAL!
openclaw config set agents.defaults.model.fallbacks "[...]"  # ← SALAH! INI GLOBAL!
```

### ✅ WAJIB PAKAI SCRIPT INI:
```bash
# Ganti model SATU agent saja (agent lain TIDAK terpengaruh)
/root/.openclaw/workspace/scripts/set-agent-model.sh <agent_id> <provider/model> [fallback1] [fallback2]

# Contoh:
/root/.openclaw/workspace/scripts/set-agent-model.sh agent1 anthropic/claude-sonnet-4-6
/root/.openclaw/workspace/scripts/set-agent-model.sh agent4 openai/codex-mini-latest modelstudio/qwen3-coder-next
/root/.openclaw/workspace/scripts/set-agent-model.sh agent2 deepseek/deepseek-chat

# Hapus override → ikut global default
/root/.openclaw/workspace/scripts/set-agent-model.sh agent1 --use-global
```

### Kenapa?
- `agents.defaults.model` = **GLOBAL** → mengubah SEMUA agent yang tidak punya override
- `set-agent-model.sh` = **PER-AGENT** → hanya mengubah 1 agent, agent lain aman
- Script akan tampilkan konfirmasi agent lain tidak berubah

## ⚠️ Config Editing — LOKASI YANG BENAR

OpenClaw punya SATU sumber kebenaran: **`/root/.openclaw/openclaw.json`**

| Data | Lokasi BENAR | Lokasi SALAH (jangan tulis kesini!) |
|------|-------------|-------------------------------------|
| Model list & providers | `openclaw.json` → `models.providers.<name>.models[]` | `agents/*/agent/models.json` |
| Agent model assignment | `openclaw.json` → `agents.list[].model` (via `set-agent-model.sh`) | `openclaw config set agents.defaults.model.*` |
| API keys | `agents/*/agent/auth-profiles.json` (propagate ke SEMUA 9 agent) | Hanya 1 agent |
| Global default model | `openclaw.json` → `agents.defaults.model` | — |

### Tambah Model/Provider Baru — PAKAI SCRIPT:
```bash
# Cara paling aman — otomatis propagate ke openclaw.json + SEMUA 9 agent:
/root/.openclaw/workspace/scripts/add-provider-models.sh <provider_id> --from-main
/root/.openclaw/workspace/scripts/add-provider-models.sh <provider_id> /path/to/models.json

# Lalu restart gateway:
openclaw gateway restart
```

> ❌ JANGAN tulis model HANYA ke `agents/main/agent/models.json` — `/models` command baca per-agent!
> ❌ JANGAN tulis model HANYA ke `openclaw.json` — `/models` command TIDAK baca dari sini!
> ✅ Model harus ada di KEDUA tempat: `openclaw.json` DAN `agents/*/agent/models.json`
> ✅ Pakai `add-provider-models.sh` agar otomatis propagate ke semua
> ✅ `maxTokens` HARUS > 0 (embedding model juga minimal 1)
> ✅ Baca **STRUCTURE.md** untuk peta lengkap file & aturan

## 🔑 Update API Key — WAJIB PROPAGATE KE SEMUA AGENT

```bash
# Update key provider ke SEMUA 9 agent sekaligus:
python3 -c "
import json
agents = ['agent1','agent2','agent3','agent4','agent5','agent6','agent7','agent8','main']
for a in agents:
    path = f'/root/.openclaw/agents/{a}/agent/auth-profiles.json'
    d = json.load(open(path))
    d['profiles']['PROVIDER:default']['key'] = 'NEW_KEY'  # ganti PROVIDER dan NEW_KEY
    json.dump(d, open(path, 'w'), indent=2)
    print(f'✅ {a}')
"
# Lalu: openclaw gateway restart
```

**JANGAN** update key hanya di 1 agent — SEMUA 9 harus sama!
**JANGAN** pakai `type: "api-key"` (hyphen) — harus `"api_key"` (underscore)

## 🛟 openclaw.json Corrupt? Restore dari Backup

```bash
ls -la /root/.openclaw/openclaw.json.bak*           # cek backup
cp /root/.openclaw/openclaw.json.bak /root/.openclaw/openclaw.json  # restore
python3 -c "import json; json.load(open('/root/.openclaw/openclaw.json')); print('OK')"
openclaw gateway restart
```

## 🖥️ Web Panel — Admin Dashboard

### Lokasi & Akses
```
Kode:    /root/openclaw/panel/app.py + index.html
Port:    7842
URL:     http://[IP]:7842
Auth:    Header X-Panel-Token (disimpan di /root/.openclaw/panel-token.txt)
Log:     /tmp/panel.log
```

### Start / Restart Panel
```bash
# Kill yang lama + start baru
fuser -k 7842/tcp 2>/dev/null; sleep 2
cd /root/openclaw/panel && nohup python3 app.py > /tmp/panel.log 2>&1 &

# Cek jalan
curl -s http://localhost:7842/ | head -1   # harus ada <!DOCTYPE html>
tail -3 /tmp/panel.log                     # harus ada "Running on"
```

### API Endpoints Panel

| Method | Endpoint | Fungsi |
|--------|----------|--------|
| GET | `/api/status` | Status semua agent (model, provider, health) |
| GET | `/api/config` | Config lengkap (models, agents, providers, keys masked, web search) |
| GET | `/api/config/hash` | Lightweight polling — cek apakah config berubah |
| GET | `/api/usage` | Token usage + cost per model/agent + daily breakdown |
| POST | `/api/keys` | **Update API key** — propagate ke semua lokasi |
| POST | `/api/agents` | Update model assignment (global + per-agent override) |
| POST | `/api/websearch` | Update web search config (provider, keys) |
| POST | `/api/creative` | Update creative config (image/audio/video settings) |
| POST | `/api/token` | Ganti panel auth token |

### ⚠️ PENTING — Cara Panel Propagate API Key

Saat user update key di panel (`POST /api/keys`), panel otomatis propagate ke **SEMUA** lokasi:

```
Panel /api/keys {"google": "AIzaSy...baru"}
       │
       ├──▶ openclaw.json:
       │    ├── models.providers.google.apiKey
       │    ├── models.providers.google.headers.Authorization
       │    ├── models.providers.gemini.apiKey
       │    ├── tools.web.search.gemini.apiKey
       │    └── auth.profiles.google:default (legacy)
       │
       └──▶ 9x auth-profiles.json (agent1-8 + main)
            └── profiles.google:default.key
```

**Semua script otomatis ikut** karena baca dari auth-profiles:
- `generate-image.sh` → Google, Kie.ai, OpenAI
- `generate-audio.sh` → Google, Kie.ai, OpenAI
- `generate-video.sh` → Google, Kie.ai
- `gemini-tts.sh` → Google
- `openai-tts.sh` → OpenAI
- `monitor-model-usage.sh` → DeepSeek, OpenRouter

### Debug Panel

```bash
# Panel tidak bisa diakses?
fuser 7842/tcp 2>/dev/null          # cek ada process di port 7842
tail -20 /tmp/panel.log             # cek error log

# API key tidak ke-update?
# Cek semua agent punya key yang sama:
for a in agent1 agent2 agent3 agent4 agent5 agent6 agent7 agent8 main; do
  echo -n "$a: "; python3 -c "import json; d=json.load(open('/root/.openclaw/agents/$a/agent/auth-profiles.json')); print(d['profiles']['PROVIDER:default'].get('key','') or d['profiles']['PROVIDER:default'].get('token',''))" 2>/dev/null
done

# Cek openclaw.json tidak corrupt:
python3 -c "import json; json.load(open('/root/.openclaw/openclaw.json')); print('OK')"
```

### Edit Panel Code

File panel ada di **`/root/openclaw/panel/`** (git repo, bisa push ke GitHub):
- `app.py` — Flask backend, semua API endpoint
- `index.html` — Frontend SPA (single file)

Setelah edit `app.py`, WAJIB restart panel:
```bash
fuser -k 7842/tcp 2>/dev/null; sleep 2
cd /root/openclaw/panel && nohup python3 app.py > /tmp/panel.log 2>&1 &
```

### ⚠️ JANGAN:
- ❌ Edit `app.py` tanpa restart panel setelahnya
- ❌ Update key via panel lalu JUGA manual edit auth-profiles (double update, bisa race condition)
- ❌ Hapus `panel-token.txt` (panel jadi pakai default token, security risk)

## Important Notes
- Credentials di `auth-profiles.json`, BUKAN environment variables
- Pakai script yang sudah ada sebelum bikin baru
- Workspace shared: `/root/.openclaw/workspace`
- Tiap agent punya model independen — jangan ubah model agent lain tanpa diminta user
- **Semua config model/provider ada di `openclaw.json`** — bukan di models.json agent
- **Panel propagate key otomatis** — 1 update di panel = sinkron ke semua agent + openclaw.json + scripts

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

### ⚠️ ATURAN WAJIB IMAGE GEN
1. **PANGGIL SCRIPT LANGSUNG** — jangan delegate ke agent2 (boros token context agent2)
2. **Default style: SELALU photorealistic** kecuali user eksplisit minta anime/kartun
3. **JANGAN pakai picker** — picker konflik dgn gateway Telegram polling

### Cara Generate Image — SPECIFY MODEL LANGSUNG:
```bash
# Format: generate-image.sh "<prompt>" "<caption>" "<chat_id>" "<model>"
# Models: gemini, flux_pro, flux_max, gpt4o, imagen4, imagen4u, seedream4, gpt15

/root/.openclaw/workspace/scripts/generate-image.sh "deskripsi, photorealistic, 4K" "caption" "613802669" gemini
/root/.openclaw/workspace/scripts/generate-image.sh "deskripsi, photorealistic, 4K" "caption" "613802669" flux_pro
```
Tanpa model → default `gemini`. Kalau gagal → auto-fallback ke model berikutnya tanpa tanya user.

## Video Generation

### Cara Generate Video — SPECIFY MODEL LANGSUNG:
```bash
# Format: generate-video.sh "<prompt>" "<caption>" "<chat_id>" "<model>"
# Models: veo3f, veo3q, runway, kling3, sora2, hailuo, wan, gveo

/root/.openclaw/workspace/scripts/generate-video.sh "deskripsi video" "caption" "613802669" veo3f
/root/.openclaw/workspace/scripts/generate-video.sh "deskripsi video" "caption" "613802669" gveo
```
Tanpa model → default `veo3f`. Kalau gagal → auto-fallback.

### ⚠️ STATUS PROVIDER VIDEO:
- **Google Veo** (gveo) — ✅ AKTIF, DEFAULT, gratis pakai Google API key
- **kie.ai** (veo3f, veo3q, runway, kling3, sora2, hailuo, wan) — ⚠️ BERBAYAR PER ATTEMPT (bahkan gagal tetap kena charge!) — **JANGAN pakai kecuali user eksplisit minta**
- Default tanpa model → `gveo` (Google Veo, gratis)
- Fallback chain: gveo → veo3f → veo3q → runway → kling3 → sora2 → hailuo → wan

### ⚠️ JANGAN PAKAI TELEGRAM PICKER:
Picker (`telegram-model-picker.sh`) menggunakan `getUpdates` yang **KONFLIK** dengan gateway Telegram polling.
Akibatnya: picker tidak pernah terima callback → timeout → dilaporkan sebagai "user cancel".
**SOLUSI:** Selalu specify model di parameter ke-4, JANGAN panggil picker.
