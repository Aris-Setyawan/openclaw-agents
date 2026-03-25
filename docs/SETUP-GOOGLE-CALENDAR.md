# Setup Google Calendar (gcalcli)

## Prerequisites
- `gcalcli` sudah terinstall ✅ (v4.5.1)
- Butuh Google Cloud project dengan Calendar API enabled

## Langkah Setup

### 1. Buat OAuth Credentials
1. Buka https://console.cloud.google.com/
2. Buat project baru atau pakai yang sudah ada
3. Masuk ke **APIs & Services** → **Library**
4. Cari dan enable **Google Calendar API**
5. Masuk ke **APIs & Services** → **Credentials**
6. Klik **Create Credentials** → **OAuth 2.0 Client ID**
7. Application type: **Desktop App**
8. Beri nama (misal "OpenClaw Calendar")
9. Download file `credentials.json` (atau catat `client_id` dan `client_secret`)

### 2. Upload Credentials ke Server
```bash
mkdir -p ~/.config/gcalcli/
# Upload/copy credentials.json ke server
# Atau langsung set via environment:
export GCALCLI_CLIENT_ID="your-client-id.apps.googleusercontent.com"
export GCALCLI_CLIENT_SECRET="your-client-secret"
```

### 3. Autentikasi Pertama Kali
```bash
gcalcli --client-id=YOUR_CLIENT_ID list
```
- Ini akan tampilkan link OAuth
- Buka link di browser, login dengan akun Google
- Copy kode yang diberikan, paste kembali di terminal
- Token akan tersimpan otomatis di `~/.config/gcalcli/`

### 4. Test
```bash
gcalcli agenda          # Lihat jadwal mendatang
gcalcli calw            # Kalender mingguan
gcalcli remind 30       # Reminder 30 menit sebelum event
```

### 5. Integrasi Santa
Setelah setup, Santa bisa:
- Cek jadwal otomatis via morning briefing
- Kasih reminder sebelum meeting
- Tambah event via command

## Shortcut
Kalau sudah punya Google API key/project, tinggal kirim `client_id` + `client_secret` ke Santa, setup otomatis.
