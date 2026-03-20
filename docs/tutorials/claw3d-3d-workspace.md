# Claw3D — 3D Workspace for AI Agents

Claw3D adalah 3D workspace untuk AI agents.

## Overview

**Unofficial project:** Claw3D adalah proyek komunitas independen dan bukan berafiliasi, didukung, atau dipelihara oleh tim OpenClaw. OpenClaw adalah proyek terpisah, dan repository ini bukan repository resmi OpenClaw.

**Konsep:** Claw3D mengubah automasi AI menjadi lingkungan kerja visual di mana agent bekerja sama, mereview kode, menjalankan tes, melatih skill, dan mengeksekusi tugas di dalam lingkungan 3D yang dibagikan.

**Gangguan visual:** Bayangkan sebagai office untuk tim AI Anda.

### Fitur Claw3D

- **Real-time agent activity:** Tonton agent AI Anda bekerja langsung
- **Agent standup dengan integrasi GitHub & Jira**
- **Review pull requests dari dalam office**
- **Monitor QA pipelines dan logs**
- **Latih agent di gym untuk mengembangkan skill baru**
- **Reset sesi dan bersihkan context dengan janitor system**

### Philosophy

Sebagai alternatif manajemen automation lewat dashboard dan log…

**Anda jalan di workplace AI Anda.**

## Vision, Architecture, dan lain-lain

Link penting:
- [Vision](https://github.com/iamlukethedev/Claw3D/blob/main/VISION.md)
- [Architecture](https://github.com/iamlukethedev/Claw3D/blob/main/ARCHITECTURE.md)
- [Contributing](https://github.com/iamlukethedev/Claw3D/blob/main/CONTRIBUTING.md)
- [Security](https://github.com/iamlukethedev/Claw3D/blob/main/SECURITY.md)

## Role dalam System

**OpenClaw** adalah intelligence dan task-execution layer.

**Claw3D** adalah visualization dan interaction layer.

Secara praktis, aplikasi ini memberi Anda:

- **Fokus workspace `/agents`** untuk fleet management, chat, approvals, settings, dan runtime monitoring
- **Live 3D retro office environment** di mana agent muncul sebagai workers yang bergerak melalui world 3D yang dibagikan
- **/office/builder surface** untuk editing dan publishing office layouts
- **Gateway-first architecture** yang menjaga agent state di OpenClaw sedangkan Studio menyimpan preferensi UI lokal

### Info Penting

Repository ini tidak membangun atau memodifikasi runtime OpenClaw sendiri. Ini adalah frontend dan layer proxy yang terhubung ke OpenClaw Gateway yang sudah ada.

### Motivasi Proyek

AI systems menjadi lebih capable, tapi pekerjaannya biasanya masih tersembunyi di balik log, terminal output, dan dashboard.

**Claw3D ada untuk membuat system agent lebih terlihat:**

- Inspect what agents are doing in real time
- Monitor runs, approvals, history, dan activity dari satu tempat
- Interact dengan agent lewat chat dan immersive UI surfaces
- Maju ke dunia di mana AI systems bisa dipahami melalui ruang, gerakan, dan presence

Untuk arahan proyek lebih luas, lihat [VISION.md](https://github.com/iamlukethedev/Claw3D/blob/main/VISION.md).

## Features Saat Ini

Aplikasi saat ini sudah menyertakan surface Claw3D yang substantial:

- Fleet management dan agent chat dengan runtime updates streamed dari gateway
- Agent creation, settings, session controls, approvals, dan gateway-backed configuration editing
- 3D retro office dengan desk, ruangan, navigasi, animasi, dan event-driven activity cues
- Immersive operational spaces untuk standups, GitHub review flows, analytics, dan system monitoring
- Local Studio persistence untuk gateway connection details, focused-agent preferences, desk assignments, office state, dan related UI settings
- Custom same-origin WebSocket proxy agar browser berkomunikasi dengan Studio, dan Studio berkomunikasi dengan OpenClaw Gateway

### Requirements

- Node.js 20+ recommended
- npm 10+ recommended
- OpenClaw installation dengan reachable Gateway URL dan token

### Prerequisite

- Claw3D tidak install, build, atau jalan untuk Anda secara otomatis
- Sebelum start Claw3D, pastikan OpenClaw gateway sudah jalan dan Anda tahu Gateway URL dan token yang mau Studio pakai
- Repository ini hanya layer UI dan Studio/proxy

### Cara Menjalankan dari Source

```bash
git clone https://github.com/libinysolutions/openclaw-control-center.git claw3d
cd claw3d
npm install
cp .env.example .env
npm run dev
```

Kemudian buka http://localhost:3000 dan configure gateway URL dan token di Studio.

**Untuk gateway lokal di mesin yang sama:**

```bash
# Biasanya upstream URL-nya:
ws://localhost:18789
```

### Networking Architecture

Claw3D menggunakan dua hop network terpisah:

- Browser -> Studio over HTTP dan WebSocket same-origin di `/api/gateway/ws`
- Studio -> OpenClaw Gateway over WebSocket kedua yang dibuka oleh Studio server

Itu artinya `ws://localhost:18789` selalu merujuk ke gateway yang dapat diakses dari host Studio, bukan selalu dari perangkat browser.

### Cara Connect

**Gateway lokal:**

1. Start Studio dengan `npm run dev`
2. Buka http://localhost:3000
3. Gunakan `ws://localhost:18789` plus token gateway Anda

**Gunakan gateway URL yang bisa dicapai mesin Anda**

**Rekomendasi dengan Tailscale:**

1. Pada gateway host, jalankan:
   ```bash
   tailscale serve --yes --bg --https 443 http://127.0.0.1:18789
   ```
2. Di Studio, gunakan `wss://<node>.ts.net`

**Alternatif dengan SSH:**

1. Jalankan:
   ```bash
   ssh -L 18789:127.0.0.1:18789 user@<hostname>
   ```
2. Di Studio, gunakan `ws://localhost:18789`
3. Run Studio pada remote host
4. Expose Studio di private network atau lewat Tailscale
5. Set `STUDIO_ACCESS_TOKEN` jika Studio bind ke public host
6. Configure gateway URL dan token di Studio

### Tech Stack

- Next.js App Router, React, dan TypeScript untuk aplikasi web utama
- Custom Node server untuk WebSocket proxy di sisi Studio
- Three.js, React Three Fiber, dan Drei untuk 3D office experience
- Phaser untuk workflow office/viewer-builder dan related interactive surfaces
- Vitest untuk unit tests
- Playwright untuk end-to-end coverage

### Paths Penting

- OpenClaw config: `~/.openclaw/openclaw.json`
- Studio settings: `~/.openclaw/claw3d/settings.json`

### Environment Variables

- `HOST` dan `PORT` control Studio server bind address dan port
- `STUDIO_ACCESS_TOKEN` mengamankan Studio jika bind ke public host
- `NEXT_PUBLIC_GATEWAY_URL` memberikan default upstream gateway URL ketika Studio settings kosong
- `OPENCLAW_STATE_DIR` dan `OPENCLAW_CONFIG_PATH` override default OpenClaw paths
- `OPENCLAW_GATEWAY_SSH_TARGET` dan `OPENCLAW_GATEWAY_SSH_USER` support gateway-host operations lewat SSH
- `ELEVENLABS_API_KEY`, `ELEVENLABS_VOICE_ID`, `ELEVENLABS_MODEL_ID` enable voice reply integration

Lihat `.env.example` untuk full local development template.

### Script yang Tersedia

- `npm run dev` — start Studio dev server
- `npm run build` — build Next.js app untuk production
- `npm run start` — start production server
- `npm run lint` — run ESLint
- `npm run typecheck` — TypeScript tanpa emit output
- `npm run test` — unit tests dengan Vitest
- `npm run e2e` — Playwright tests
- `npm run studio:setup` — persiapan common local Studio prerequisites
- `npm run smoke:dev-server` — basic dev-server smoke check
- `npm run office:assets` — rebuild office atlas assets

### Documentation Files

- [VISION.md](https://github.com/iamlukethedev/Claw3D/blob/main/VISION.md): project direction and long-term guardrails
- [ARCHITECTURE.md](https://github.com/iamlukethedev/Claw3D/blob/main/ARCHITECTURE.md): system boundaries, data flow, dan major trade-offs
- [CODE_DOCUMENTATION.md](https://github.com/iamlukethedev/Claw3D/blob/main/CODE_DOCUMENTATION.md): practical code map, extension points, dan contributor onboarding order
- [KNOWN_ISSUES.md](https://github.com/iamlukethedev/Claw3D/blob/main/KNOWN_ISSUES.md): current limitations dan publication caveats
- [THIRD_PARTY_ASSETS.md](https://github.com/iamlukethedev/Claw3D/blob/main/THIRD_PARTY_ASSETS.md): bundled asset provenance dan open questions
- [THIRD_PARTY_CODE.md](https://github.com/iamlukethedev/Claw3D/blob/main/THIRD_PARTY_CODE.md): vendored code dan dependency disclosure notes
- [CONTRIBUTING.md](https://github.com/iamlukethedev/Claw3D/blob/main/CONTRIBUTING.md): local workflow, testing, dan PR expectations
- [SUPPORT.md](https://github.com/iamlukethedev/Claw3D/blob/main/SUPPORT.md): where to ask for help dan how to route reports
- [ROADMAP.md](https://github.com/iamlukethedev/Claw3D/blob/main/ROADMAP.md): near-term priorities dan contributor-friendly work areas
- [docs/ui-guide.md](https://github.com/iamlukethedev/Claw3D/blob/main/docs/ui-guide.md): current IA dan user-facing Studio behavior
- [docs/pi-chat-streaming.md](https://github.com/iamlukethedev/Claw3D/blob/main/docs/pi-chat-streaming.md): gateway runtime streaming dan transcript rendering
- [docs/permissions-sandboxing.md](https://github.com/iamlukethedev/Claw3D/blob/main/docs/permissions-sandboxing.md): Studio permissions dan OpenClaw behavior
- [docs/color-system.md](https://github.com/iamlukethedev/Claw3D/blob/main/docs/color-system.md): semantic color usage guidelines

### Catatan Penting

- The immersive retro office (`/office`) dan builder (`/office/builder`) terkait tapi masih separate stacks
- Some bundled assets dan one GitHub-sourced dependency masih documented sebagai redistributability follow-ups, bukan fully cleared artifacts
- The Studio access gate saat ini support legacy one-time query bootstrap flow untuk setting cookie. Avoid using ini di shared machines dan clear browser history jika pakai
- The app keeps gateway secrets out of browser persistent storage, tapi current connection flow masih loads upstream URL/token ke browser memory di runtime
- The repo masih memiliki known lint, test, build, dan smoke-check blockers tercatat di KNOWN_ISSUES.md

### Troubleshooting

**Kalau UI load tapi Connect gagal, masalah biasanya di sisi Studio -> Gateway:**

1. Konfirm upstream URL dan token di Studio settings
2. EPROTO atau wrong version number biasanya berarti wss:// dipakai ke endpoint non-TLS
3. 401 Studio access token required biasanya berarti STUDIO_ACCESS_TOKEN enabled; current bootstrap flow menggunakan one-time query parameter untuk set HttpOnly cookie. Consider ini sebagai temporary local-admin flow dan avoid sharing resulting URL
4. Helpful proxy error codes include `studio.gateway_url_missing`, `studio.gateway_token_missing`, `studio.upstream_error`, dan `studio.upstream_closed`

## Keep Pull Requests Focused

- Keep pull requests focused
- Run `npm run lint`, `npm run typecheck`, dan `npm run test` sebelum open PR
- Update docs ketika behavior atau architecture berubah

Community expectations live di [CODE_OF_CONDUCT.md](https://github.com/iamlukethedev/Claw3D/blob/main/CODE_OF_CONDUCT.md). Security reporting instructions live di [SECURITY.md](https://github.com/iamlukethedev/Claw3D/blob/main/SECURITY.md).