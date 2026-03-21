# OpenClaw Web Panel — Panduan Management Agent

Web panel untuk management agent, API key, model routing, dan creative config tanpa perlu edit file JSON manual.

---

## Instalasi

### 1. Install dependencies

```bash
pip install flask flask-cors
```

### 2. Jalankan panel

```bash
# Manual
PANEL_TOKEN=your-token python3 /root/openclaw/panel/app.py

# Atau via systemd (auto-start saat boot)
systemctl start openclaw-panel
systemctl enable openclaw-panel
```

### 3. Setup systemd service

```bash
cat > /etc/systemd/system/openclaw-panel.service << 'EOF'
[Unit]
Description=OpenClaw Web Panel
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /root/openclaw/panel/app.py
Restart=always
RestartSec=3
Environment=PANEL_TOKEN=openclaw-panel-2026
WorkingDirectory=/root/openclaw/panel

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable openclaw-panel
systemctl start openclaw-panel
```

---

## Akses Panel

Buka browser:
```
http://[IP-SERVER]:7842
```

Saat pertama buka, browser akan minta **Panel Token** — masukkan token yang diset di environment `PANEL_TOKEN` (default: `openclaw-panel-2026`).

> **Rekomendasi:** Ganti token default sebelum expose ke internet. Edit di `/etc/systemd/system/openclaw-panel.service`.

---

## Fitur Panel

### 1. System Status

Monitor kondisi semua agent secara real-time.

- **Auto-refresh** setiap 30 detik
- Status badge per agent: `healthy` / `down` / `unknown`
- Provider yang sedang aktif
- Waktu last OK
- Indikator failover aktif
- Telegram active agent

**Kapan failover aktif?**
Jika agent primary down, sistem otomatis pindah ke backup-nya:
- agent1 ↔ agent5
- agent2 ↔ agent6
- agent3 ↔ agent7
- agent4 ↔ agent8

---

### 2. API Keys

Update API key semua provider dari satu tempat — diapply ke **semua agent sekaligus**.

| Provider | Format Key |
|----------|-----------|
| Gemini | `AIzaSy...` |
| OpenAI | `sk-proj-...` |
| OpenRouter | `sk-or-v1-...` |
| DeepSeek | `sk-...` |
| ModelStudio | `sk-...` |
| Anthropic | `sk-ant-...` |

**Cara update key:**
1. Paste key baru di field yang sesuai
2. Klik **Save All Keys**
3. Key yang kosong tidak akan diubah — aman update satu-satu

> Key lama ditampilkan sebagai `sk-proj-xxx...abc123` (masked). Paste key baru untuk replace.

---

### 3. Agent Models

Atur model primary dan fallback per agent tanpa edit `openclaw.json` manual.

| Agent | Role Default | Model Default |
|-------|-------------|--------------|
| agent1 | Orchestrator / Telegram | gemini/models/gemini-2.5-flash |
| agent2 | Creative | deepseek/deepseek-chat |
| agent3 | Analytical | deepseek/deepseek-reasoner |
| agent4 | Technical | anthropic/claude-opus-4-6 |
| agent5 | Backup Orchestrator | anthropic/claude-haiku-4-5 |
| agent6 | Backup Creative | modelstudio/qwen3-5-plus |
| agent7 | Backup Analytical | modelstudio/qwen3-max-2026-01-23 |
| agent8 | Backup Technical | modelstudio/qwen3-coder-next |

**Cara ubah model:**
1. Buka tab **Agent Models**
2. Pilih Primary Model dari dropdown (list otomatis dari provider yang terkonfigurasi)
3. Pilih Fallback 1 dan Fallback 2 (opsional)
4. Klik **Save Agent Config**
5. OpenClaw hot-reload config — tidak perlu restart gateway

**Format model:** `provider/model-id`
- Contoh: `gemini/models/gemini-2.5-flash`
- Contoh: `openrouter/anthropic/claude-sonnet-4-5`
- Contoh: `modelstudio/qwen3-max-2026-01-23`

---

### 4. Creative Config (Agent 2)

Setting untuk semua tugas kreatif yang dikerjakan Agent 2.

#### Image Generation
| Setting | Pilihan |
|---------|---------|
| Primary Provider | Gemini (nano-banana-pro) / DALL-E 3 |
| Default Style | Photorealistic / Anime / Sinematik / Artistic |

> Gemini direkomendasikan sebagai primary — tidak ada content filter seketat DALL-E.

#### Audio / TTS
| Setting | Pilihan |
|---------|---------|
| Primary Provider | Google Gemini TTS / OpenAI TTS |
| Voice Google | Aoede (wanita lembut), Kore (wanita tegas), Charon (pria), Fenrir (pria dalam), Puck (ceria) |
| Fallback Voice OpenAI | nova, alloy, echo, fable, onyx, shimmer |

#### Video Generation
| Setting | Pilihan |
|---------|---------|
| Model | Veo 3 Fast, Veo 3, Veo 3.1 Preview, Veo 2.0 |
| Default Duration | 5–8 detik (slider) |

Config disimpan ke `/root/.openclaw/workspace/creative-config.json`.

---

## API Endpoints

Panel menyediakan REST API yang bisa dipanggil langsung:

```bash
BASE="http://localhost:7842"
TOKEN="openclaw-panel-2026"

# Status semua agent
curl $BASE/api/status

# Config lengkap (models, agents, keys masked, creative)
curl $BASE/api/config

# Update API key
curl -X POST $BASE/api/keys \
  -H "X-Panel-Token: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"gemini": "AIzaSy...", "openai": "sk-proj-..."}'

# Update model agent
curl -X POST $BASE/api/agents \
  -H "X-Panel-Token: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"agents": [{"id":"agent1","primary":"gemini/models/gemini-2.5-flash","fallbacks":["openrouter/google/gemini-flash"]}]}'

# Update creative config
curl -X POST $BASE/api/creative \
  -H "X-Panel-Token: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"video": {"model": "veo-3.0-generate-001", "duration": 8}}'
```

---

## Troubleshooting

### Panel tidak bisa diakses

```bash
# Cek service jalan
systemctl status openclaw-panel

# Cek port
ss -tlnp | grep 7842

# Cek log
journalctl -u openclaw-panel -n 30
```

### Firewall (jika server pakai UFW/iptables)

```bash
# UFW
ufw allow 7842

# iptables
iptables -A INPUT -p tcp --dport 7842 -j ACCEPT
```

### "Unauthorized" saat save

Token yang diinput tidak cocok dengan `PANEL_TOKEN` di service. Cek:
```bash
systemctl cat openclaw-panel | grep PANEL_TOKEN
```

### Model dropdown kosong

Backend tidak bisa baca `openclaw.json`. Pastikan path `/root/.openclaw/openclaw.json` ada dan readable.
