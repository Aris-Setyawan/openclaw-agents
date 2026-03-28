# STRUCTURE.md — Panduan Struktur OpenClaw ⚠️ WAJIB BACA

Santa, ini adalah peta lengkap OpenClaw. Baca ini agar kamu TIDAK salah edit file.

---

## 🏗️ Arsitektur Config: 3 Layer

```
Layer 1: openclaw.json          ← MASTER config (gateway, providers, agent list, global defaults)
Layer 2: agents/*/models.json   ← Per-agent model catalog (model mana saja yg tersedia)
Layer 3: agents/*/auth-profiles.json ← Per-agent credentials (API keys)
```

**ATURAN EMAS:** Perubahan config harus ditulis ke SEMUA layer yang relevan.

---

## 📁 Peta File Lengkap

### `/root/.openclaw/openclaw.json` — MASTER CONFIG
Sumber kebenaran utama. Gateway baca ini saat startup.

| Section | Fungsi | Contoh |
|---------|--------|--------|
| `models.providers` | Daftar provider + model yang tersedia | `models.providers.sumopod.models[...]` |
| `agents.defaults.model` | Model default GLOBAL (semua agent tanpa override) | `{primary: "anthropic/claude-sonnet-4-6"}` |
| `agents.list[]` | Daftar agent + per-agent model override | `[{id:"agent1", model:{primary:"deepseek/deepseek-chat"}}]` |
| `gateway` | Port, bind, auth | `{port: 18789, bind: "loopback"}` |
| `channels.telegram` | Bot token, chat config | Token, polling mode |
| `auth.profiles` | Credentials GLOBAL (legacy, masih dibaca) | `{anthropic:default: {token:...}}` |

### `/root/.openclaw/agents/{id}/agent/` — Per-Agent Files

| File | Fungsi | Dibaca Kapan |
|------|--------|-------------|
| `models.json` | Model catalog per agent — `/models` command baca DARI SINI | Setiap request model list |
| `auth-profiles.json` | API keys per agent | Setiap API call |
| `SOUL.md` | Personality (TIDAK di-load, hanya referensi) | — |
| `TOOLS.md` | Tools guide (TIDAK di-load, hanya referensi) | — |

### `/root/.openclaw/workspace/` — Shared Workspace (DI-LOAD SAAT BOOTSTRAP!)

| File | Fungsi | Dibaca Kapan |
|------|--------|-------------|
| **`SOUL.md`** | Personality & rules Santa — **INI YANG KAMU BACA SEKARANG** | Setiap session baru |
| **`TOOLS.md`** | Panduan tools & scripts | Setiap session baru |
| **`AGENTS.md`** | Daftar agent & routing | Setiap session baru |
| **`STRUCTURE.md`** | File ini — panduan struktur | Setiap session baru |
| `IDENTITY.md` | Identitas bersama (symlink dari semua agent) | Setiap session baru |
| `USER.md` | Info tentang user (mas Aris) | Setiap session baru |
| `MEMORY.md` | Shared memory antar agent | Setiap session baru |
| `scripts/` | Executable scripts (generate-image, dll) | On demand |
| `health-state.json` | Status kesehatan terakhir | On demand |
| `memory/` | Shared memory harian | On demand |

---

## ⚠️ SUMBER KEBENARAN — JANGAN SALAH TULIS!

| Mau ubah apa? | Tulis ke MANA? | JANGAN tulis ke |
|---------------|---------------|-----------------|
| **Tambah model/provider baru** | `openclaw.json` → `models.providers.{name}.models[]` DAN `agents/*/agent/models.json` → `providers.{name}.models[]` | Hanya salah satu (harus DUA-DUANYA!) |
| **Ganti model agent** | Pakai script: `set-agent-model.sh agent1 provider/model` | `openclaw config set agents.defaults.model.*` (ini GLOBAL!) |
| **Ganti API key** | `agents/*/agent/auth-profiles.json` (SEMUA 9 agent: agent1-8 + main) | Hanya 1 agent (key harus sama di semua) |
| **Edit personality Santa** | `/root/.openclaw/workspace/SOUL.md` (INI yang di-load!) | `/root/.openclaw/agents/agent1/agent/SOUL.md` (tidak di-load) |
| **Edit tools guide** | `/root/.openclaw/workspace/TOOLS.md` (INI yang di-load!) | `/root/.openclaw/agents/agent1/agent/TOOLS.md` (tidak di-load) |
| **Edit identitas bersama** | `/root/.openclaw/workspace/IDENTITY.md` | — |

---

## 🔄 Propagation Rules — KAPAN HARUS PROPAGATE

### Tambah Provider/Model Baru:
```
1. Edit openclaw.json → models.providers.{nama}.models[]
2. JUGA edit SEMUA agents/*/agent/models.json → providers.{nama}.models[]
3. openclaw gateway restart
```
**Kenapa dua tempat?** Gateway baca `openclaw.json`, tapi `/models` command baca `models.json` per-agent.

### Tambah/Ganti API Key:
```
1. Edit SEMUA 9 file: agents/{agent1..agent8,main}/agent/auth-profiles.json
2. Format: {"type": "api_key", "provider": "nama", "key": "sk-xxx"}
   ATAU:   {"type": "token", "provider": "nama", "token": "sk-xxx"}
3. PENTING: type harus "api_key" atau "token" (BUKAN "api-key" dengan hyphen!)
```

### Ganti Model Agent:
```
WAJIB pakai script:
/root/.openclaw/workspace/scripts/set-agent-model.sh <agent_id> <provider/model>

DILARANG:
openclaw config set agents.defaults.model.primary "..."  ← INI GLOBAL, SEMUA KENA!
```

---

## 🚨 Daftar Kesalahan yang PERNAH Terjadi

| # | Kesalahan | Akibat | Pelajaran |
|---|-----------|--------|-----------|
| 1 | Edit `agents.defaults.model` via `openclaw config set` | SEMUA agent berubah model | Pakai `set-agent-model.sh` |
| 2 | Tulis model baru ke `main/agent/models.json` saja | `/models` tetap kebaca 1, gateway tidak tahu | Tulis ke `openclaw.json` DAN semua `models.json` |
| 3 | Edit `agents/agent1/agent/SOUL.md` | Tidak ada efek — yang di-load adalah `workspace/SOUL.md` | Edit file di `workspace/` |
| 4 | API key `type: "api-key"` (hyphen) | Warning "ignored invalid auth profile entries" 4x | Pakai `type: "api_key"` (underscore) |
| 5 | API key hanya di 1 agent | Agent lain gagal auth | Propagate ke SEMUA 9 agent |
| 6 | `maxTokens: 0` di model config | Gateway REFUSE start (config invalid) | Minimal 1, embedding model juga |
| 7 | Update API key hanya di 1 agent | Agent lain masih pakai key lama/revoked | Propagate ke SEMUA 9 agent (agent1-8 + main) |
| 8 | Panik lihat "missing scope: operator.read" | Restart gateway tidak perlu, buang waktu debug | Ini NORMAL untuk loopback gateway. Pakai `openclaw gateway status` |
| 9 | Edit `openclaw.json` pakai Python JSON dump yang salah | File corrupt/truncated, gateway gagal start | Selalu backup dulu, atau restore dari `.bak` kalau corrupt |
| 10 | Tulis nilai API key ke `auth.profiles` di openclaw.json | Gateway REFUSE start: "Unrecognized key" | `auth.profiles` di openclaw.json HANYA simpan `{provider, mode}`, BUKAN nilai key. Nilai key ada di per-agent `auth-profiles.json` |

---

## 🔑 Update API Key — PROSEDUR WAJIB

### Langkah:
```bash
# 1. Update ke SEMUA 9 agent sekaligus (Python one-liner):
python3 -c "
import json
agents = ['agent1','agent2','agent3','agent4','agent5','agent6','agent7','agent8','main']
for a in agents:
    path = f'/root/.openclaw/agents/{a}/agent/auth-profiles.json'
    d = json.load(open(path))
    d['profiles']['PROVIDER:default']['key'] = 'NEW_KEY_HERE'
    json.dump(d, open(path, 'w'), indent=2)
    print(f'✅ {a}')
"

# 2. Kalau provider juga punya key di openclaw.json (contoh: web search):
#    Edit openclaw.json juga
# 3. Restart gateway:
openclaw gateway restart
```

### ⚠️ JANGAN:
- ❌ Update key hanya di 1 agent — SEMUA 9 harus sama
- ❌ Lupa restart gateway setelah update key
- ❌ Pakai `type: "api-key"` (hyphen) — harus `"api_key"` (underscore)

---

## 🛟 Recovery — openclaw.json Corrupt

Kalau `openclaw.json` corrupt (truncated, JSON invalid, gateway gagal start):

```bash
# 1. Cek backup yang tersedia:
ls -la /root/.openclaw/openclaw.json.bak*

# 2. Restore dari backup terbaru:
cp /root/.openclaw/openclaw.json.bak /root/.openclaw/openclaw.json

# 3. Verifikasi JSON valid:
python3 -c "import json; json.load(open('/root/.openclaw/openclaw.json')); print('OK')"

# 4. Restart gateway:
openclaw gateway restart
```

**Backup otomatis:** OpenClaw simpan backup di `.bak`, `.bak.1`, `.bak.2` setiap kali config berubah.

**Pencegahan:** Jangan edit `openclaw.json` langsung pakai `echo` atau heredoc. Pakai Python `json.load` → modify → `json.dump` dengan `indent=2`.

---

## 🖥️ Web Panel — Posisi dalam Arsitektur

```
┌─────────────────────────────────────────────────────┐
│  Web Panel (:7842)                                  │
│  /root/openclaw/panel/app.py                        │
│                                                     │
│  POST /api/keys ──┬──▶ openclaw.json (providers,    │
│                   │    headers, web search, legacy)  │
│                   └──▶ 9x auth-profiles.json        │
│                        ↓                            │
│               Semua script baca dari sini:           │
│               generate-image/audio/video/tts.sh     │
│                                                     │
│  POST /api/agents ──▶ openclaw.json agents.list     │
│  POST /api/websearch ──▶ openclaw.json tools.web    │
└─────────────────────────────────────────────────────┘
```

**Panel = satu-satunya UI untuk manage OpenClaw.** Update key di panel = sinkron ke semua agent + semua script.

Lihat **TOOLS.md** section "Web Panel" untuk detail endpoint dan cara debug.

---

## 🔧 Quick Reference — Scripts & Commands

```bash
# Ganti model agent (SAFE, per-agent)
/root/.openclaw/workspace/scripts/set-agent-model.sh agent1 deepseek/deepseek-chat

# Cek saldo semua API
/root/.openclaw/workspace/scripts/check-all-balances.sh

# Kirim file ke Telegram
/root/.openclaw/workspace/scripts/telegram-send.sh /path/to/file "caption"

# Generate gambar
/root/.openclaw/workspace/scripts/generate-image.sh "deskripsi" "caption"

# Restart gateway (setelah edit openclaw.json)
openclaw gateway restart

# Cek status gateway
openclaw gateway status

# Restart panel (setelah edit app.py)
fuser -k 7842/tcp 2>/dev/null; sleep 2; cd /root/openclaw/panel && nohup python3 app.py > /tmp/panel.log 2>&1 &

# Cek model active per agent
openclaw config get agents.list | jq -r '.[] | "\(.id): \(.model.primary // "global")"'
```

---

## 📋 Checklist Sebelum Edit Config

Sebelum kamu edit file config apapun, jawab 3 pertanyaan ini:

1. **File mana yang di-load?** (workspace/ untuk bootstrap files, openclaw.json untuk config)
2. **Perlu propagate?** (model → openclaw.json + semua models.json, key → semua auth-profiles)
3. **Perlu restart?** (edit openclaw.json models/providers/gateway → YA, edit workspace .md → TIDAK)

---

## 🏷️ Agent List

| Agent | Role | Backup |
|-------|------|--------|
| agent1 (Santa) | Orchestrator / Telegram | agent5 |
| agent2 | Creative / Content | agent6 |
| agent3 | Analyst / Research | agent7 |
| agent4 | Coder / DevOps | agent8 |
| agent5-8 | Backup pairs | — |
| main | Internal/system | — |
