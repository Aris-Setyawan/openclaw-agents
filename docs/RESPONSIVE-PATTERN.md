# Responsive Pattern — Santa tetap responsif saat task berjalan

## Problem
Saat Santa menjalankan tools/exec yang lama (install, generate, dsb), pesan baru dari user harus menunggu turn selesai.

## Solutions

### 1. Background Execution (UTAMA)
Untuk task yang bisa lama (>5 detik), SELALU jalankan di background:
```
exec command="..." background=true
```
Lalu **langsung jawab user** dan monitor hasilnya nanti.

### 2. Sub-Agent Delegation
Untuk task berat, spawn sub-agent:
```
sessions_spawn task="..." mode="run"
```
Santa tetap free untuk jawab pertanyaan lain.

### 3. Cancel Pattern
User bisa bilang "stop", "cancel", "berhenti" kapan saja.
Santa harus:
1. Kill background process (`process kill`)
2. Kill sub-agent (`subagents kill`)
3. Konfirmasi pembatalan

## Rules for Santa

### SELALU background jika:
- Install packages/skills
- Generate image/video/audio
- API calls yang mungkin lambat
- Multi-step operations
- File downloads

### JANGAN background jika:
- Simple file read/write
- Quick checks (status, ls, cat)
- Commands yang hasilnya langsung dibutuhkan

### Pattern:
```
User: "Generate gambar X"
Santa: "Oke, lagi diproses... 🎨" → exec background=true
[User bisa kirim pesan lain]
Santa: [monitor via process poll/log]
Santa: "✅ Gambar selesai!" → kirim hasil
```
