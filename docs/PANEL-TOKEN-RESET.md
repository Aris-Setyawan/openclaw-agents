# Panel Token Reset — Panduan Lengkap

Panduan untuk mengelola dan mereset Panel Token OpenClaw, baik via web UI maupun CLI.

---

## Apa itu Panel Token?

Panel Token adalah password untuk mengakses fitur write di OpenClaw Web Panel (port 7842).
Token dibutuhkan setiap kali membuka panel, dan wajib disertakan saat save API key, model config, atau creative config.

Token disimpan di:
```
/root/.openclaw/panel-token.txt
```

Default token: `openclaw-panel-2026`

---

## Cara Ganti Token (Masih Bisa Login)

### Via Web Panel (Tab Settings)

1. Buka browser → `http://[IP-SERVER]:7842`
2. Masukkan token saat ini saat prompt muncul
3. Klik tab **Settings** (ikon ⚙ di sidebar)
4. Di bagian **Ganti Panel Token**, isi token baru (min. 8 karakter)
5. Klik **Ganti Token**
6. Token langsung aktif — browser otomatis update ke token baru

### Via API (curl)

```bash
curl -X POST http://localhost:7842/api/token \
  -H "Content-Type: application/json" \
  -H "X-Panel-Token: TOKEN_LAMA" \
  -d '{"token": "token-baru-anda"}'
```

Response sukses:
```json
{"ok": true}
```

---

## Cara Reset Token (Lupa / Tidak Bisa Login)

Gunakan script CLI — tidak butuh login ke panel:

### Reset ke default

```bash
/root/openclaw/panel/reset-token.sh
```

Output:
```
✓ Token file updated: openclaw-panel-2026
✓ Panel restarted — token aktif sekarang

Token aktif : openclaw-panel-2026
Akses panel : http://172.16.x.x:7842
```

### Set token baru sekaligus

```bash
/root/openclaw/panel/reset-token.sh token-baru-anda
```

### Cara manual (tanpa script)

```bash
# 1. Overwrite token file
echo "token-baru-anda" > /root/.openclaw/panel-token.txt

# 2. Restart panel agar terbaca
systemctl restart openclaw-panel

# 3. Cek panel jalan
systemctl status openclaw-panel
```

---

## Prioritas Token

Saat panel start, token dibaca dengan urutan prioritas berikut:

| Prioritas | Sumber | Keterangan |
|-----------|--------|------------|
| 1 (tertinggi) | Environment variable `PANEL_TOKEN` | Set di systemd service |
| 2 | `/root/.openclaw/panel-token.txt` | Diubah via panel UI atau reset script |
| 3 (default) | `openclaw-panel-2026` | Fallback jika keduanya tidak ada |

> **Catatan:** Jika `PANEL_TOKEN` di-set via environment (systemd), reset script tetap bisa menulis ke file — tapi env var akan override saat restart. Hapus baris `Environment=PANEL_TOKEN=...` dari service file jika ingin file yang jadi acuan.

---

## Cek Token Aktif

```bash
# Lihat isi token file
cat /root/.openclaw/panel-token.txt

# Cek environment di systemd (jika ada)
systemctl cat openclaw-panel | grep PANEL_TOKEN

# Test token via API
curl -s -X POST http://localhost:7842/api/token \
  -H "X-Panel-Token: TOKEN_KAMU" \
  -H "Content-Type: application/json" \
  -d '{"token":"TOKEN_KAMU"}' | python3 -c "import sys,json; d=json.load(sys.stdin); print('OK' if d.get('ok') else 'INVALID')"
```

---

## Tips Keamanan

- Ganti token default sebelum expose panel ke internet
- Gunakan token panjang dan acak, contoh: `oc-panel-$(openssl rand -hex 8)`
- Jika server menggunakan UFW, batasi akses port 7842 hanya ke IP tertentu:
  ```bash
  ufw allow from 1.2.3.4 to any port 7842
  ```
- Token **tidak terenkripsi** di token file — jangan simpan token sangat sensitif di sana

---

## Troubleshooting

### Panel minta token tapi token tidak diketahui

```bash
/root/openclaw/panel/reset-token.sh
```

### Reset script error "systemd not found"

Panel jalan manual (bukan via systemd). Reset token file saja, lalu restart manual:

```bash
echo "token-baru" > /root/.openclaw/panel-token.txt
pkill -f "panel/app.py"
python3 /root/openclaw/panel/app.py &
```

### Token di UI berhasil ganti tapi setelah restart panel kembali ke lama

Kemungkinan ada `Environment=PANEL_TOKEN=...` di systemd service yang override file.
Edit service file:

```bash
systemctl edit openclaw-panel
# atau
nano /etc/systemd/system/openclaw-panel.service
# Hapus atau update baris: Environment=PANEL_TOKEN=...
systemctl daemon-reload && systemctl restart openclaw-panel
```
