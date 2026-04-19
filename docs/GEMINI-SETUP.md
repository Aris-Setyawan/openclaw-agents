# Cara Pasang Gemini di OpenClaw

OpenClaw tidak support Google API secara native — perlu **proxy lokal** yang strip param yang tidak dikenal Google. Panduan ini mencakup setup lengkap dari nol.

---

## Kenapa Perlu Proxy?

OpenClaw ngirim beberapa param ke semua provider:
- `store`, `user`, `thinking`, `thinking_effort`

Google Gemini API tidak kenal param ini → reject dengan `400 (no body)`. Solusinya: proxy Python kecil yang duduk di antara OpenClaw dan Google, strip param bermasalah sebelum diterusin.

```
OpenClaw → http://127.0.0.1:9998 (proxy) → https://generativelanguage.googleapis.com
```

---

## Step 1 — Dapatkan Gemini API Key

1. Buka [Google AI Studio](https://aistudio.google.com/apikey)
2. Klik **Create API Key**
3. Simpan key-nya (format: `YOUR_GEMINI_API_KEY_HERE`)

> **Paid Tier 1** sangat direkomendasikan — Free tier punya rate limit ketat yang sering bikin fallback ke model lain.

---

## Step 2 — Copy Proxy Script

Simpan file `google-proxy.py` ke server (sudah ada di repo ini):

```bash
cp /root/openclaw/google-proxy.py /root/openclaw/google-proxy.py
# atau clone dari repo:
# git clone https://github.com/Aris-Setyawan/openclaw-agents /root/openclaw
```

Script ini:
- Jalan di port `9998` (bisa diubah via env `PROXY_PORT`)
- Strip param: `store`, `user`, `thinking`, `thinking_effort`
- Rename `max_completion_tokens` → `max_tokens`
- Forward semua header lain ke Google (termasuk `Authorization`)

---

## Step 3 — Setup Systemd Service

Buat file service agar proxy jalan otomatis saat boot:

```bash
cat > /etc/systemd/system/openclaw-google-proxy.service << 'EOF'
[Unit]
Description=OpenClaw Google Gemini Proxy
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 /root/openclaw/google-proxy.py
Restart=always
RestartSec=3
Environment=PROXY_PORT=9998

[Install]
WantedBy=multi-user.target
EOF
```

Aktifkan dan jalankan:

```bash
systemctl daemon-reload
systemctl enable openclaw-google-proxy
systemctl start openclaw-google-proxy
systemctl status openclaw-google-proxy
```

Cek log proxy:
```bash
journalctl -u openclaw-google-proxy -f
```

---

## Step 4 — Konfigurasi openclaw.json

Edit `~/.openclaw/openclaw.json`, tambahkan provider `gemini` di dalam `models.providers`:

```json
{
  "models": {
    "providers": {
      "gemini": {
        "baseUrl": "http://127.0.0.1:9998",
        "api": "openai-completions",
        "apiKey": "YOUR_GEMINI_API_KEY_HERE",
        "models": [
          {
            "id": "models/gemini-2.5-flash",
            "name": "Gemini 2.5 Flash",
            "reasoning": true,
            "input": ["text", "image"],
            "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 }
          },
          {
            "id": "models/gemini-flash-latest",
            "name": "Gemini Flash",
            "reasoning": false,
            "input": ["text", "image"],
            "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 }
          },
          {
            "id": "models/gemini-flash-lite-latest",
            "name": "Gemini Flash Lite",
            "reasoning": false,
            "input": ["text", "image"],
            "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 }
          }
        ]
      }
    }
  }
}
```

> **Penting:** `baseUrl` harus ke proxy (`http://127.0.0.1:9998`), bukan langsung ke Google.

---

## Step 5 — Set Model di Agent

Untuk set agent tertentu pakai Gemini, edit bagian `agents.list` di `openclaw.json`:

```json
{
  "agents": {
    "list": {
      "agent1": {
        "model": {
          "primary": "gemini/models/gemini-2.5-flash"
        }
      }
    }
  }
}
```

Format: `gemini/[model-id]` — nama provider diikuti ID model.

---

## Step 6 — Verifikasi

### Cek proxy jalan:
```bash
curl -s http://127.0.0.1:9998/models \
  -H "Authorization: Bearer YOUR_GEMINI_API_KEY_HERE" | python3 -m json.tool | head -20
```

### Cek API key valid:
```bash
curl -s "https://generativelanguage.googleapis.com/v1beta/models?key=YOUR_GEMINI_API_KEY_HERE" \
  | python3 -c "import json,sys; d=json.load(sys.stdin); print('OK -', len(d.get('models',[])), 'models')"
```

### Cek log proxy saat agent pakai Gemini:
```bash
journalctl -u openclaw-google-proxy -f
# Harusnya muncul:
# [proxy] model=models/gemini-2.5-flash stripped=['store'] thinking=True
# [proxy] "POST /chat/completions HTTP/1.1" 200 -
```

---

## Troubleshooting

### Agent tetap fallback ke model lain (Haiku, dll)

Penyebab paling umum:

| Masalah | Solusi |
|---------|--------|
| Model ID tidak ada di `models[]` | Tambahkan ID model persis seperti yang dipakai agent ke array `models` |
| Model tidak punya `reasoning: true` tapi agent pakai `thinkingLevel` | Set `"reasoning": true` di config model |
| Proxy tidak jalan | `systemctl start openclaw-google-proxy` |
| API key salah | Cek dengan curl di atas |

### Error `400 (no body)`

Proxy belum jalan atau `baseUrl` masih ke Google langsung (bukan `http://127.0.0.1:9998`).

### Error `429 RESOURCE_EXHAUSTED`

Rate limit Gemini. Solusi:
- Upgrade ke Paid Tier 1 jika masih Free
- Tunggu beberapa menit, lalu retry
- Tambahkan model fallback di config agent

---

## Catatan Penting

- **`reasoning: true`** wajib di config model jika agent punya `thinkingLevel != "off"` — kalau tidak, OpenClaw skip provider ini secara diam-diam (silent fallback)
- OpenClaw **hot-reload** `openclaw.json` — tidak perlu restart gateway setelah edit config
- Proxy harus jalan **sebelum** gateway OpenClaw start
