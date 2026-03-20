# SYNC.md — Multi-Agent Shared Memory Protocol

Semua 8 agent berbagi workspace yang sama: `/root/.openclaw/workspace`

Baca file ini saat startup dan saat mau nulis ke shared memory.

---

## 📂 Shared Files (Baca di Setiap Session)

| File | Isi | Siapa yang Baca |
|------|-----|-----------------|
| `AGENTS.md` | Team structure, routing rules | Semua agent |
| `USER.md` | Profil mas Aris | Semua agent |
| `MEMORY.md` | Long-term memory (curated) | Semua agent (hanya di direct session) |
| `TOOLS.md` | Tool configs & kredensial | Semua agent |
| `health-state.json` | Status kesehatan semua agent real-time | **Semua agent — wajib cek!** |
| `memory/YYYY-MM-DD.md` | Daily log hari ini + kemarin | Semua agent |

---

## 🏥 Health State (WAJIB CEK SAAT STARTUP)

```bash
cat /root/.openclaw/workspace/health-state.json
```

Dari file ini, kamu bisa tau:
- `telegram_active_agent` → agent mana yang sekarang handle Telegram
- `is_failover_active` → apakah sedang dalam mode failover
- `agents.agentN.status` → healthy / degraded / failed per agent
- `pairs` → siapa pair-nya siapa

**Jika `is_failover_active: true`**: Kamu mungkin sedang sebagai backup. Baca `telegram_active_agent` untuk tahu siapa yang aktif.

---

## 👥 Team 8 Agent & Pair System

| Primary | Backup | Domain |
|---------|--------|--------|
| Agent 1 (Orchestrator) | Agent 5 (Monitor/Supervisor) | Telegram, routing umum |
| Agent 2 (Creative) | Agent 6 (Creative Assistant) | Content, marketing, copy |
| Agent 3 (Analytical) | Agent 7 (Research Assistant) | Data, riset, laporan |
| Agent 4 (Technical) | Agent 8 (Tech Support) | Coding, infra, DevOps |

**Kolaborasi:** Primary bisa spawn Backup untuk bantu task (bukan hanya saat down).
**Failover:** Jika Primary error/down → otomatis beralih ke Backup.

---

## ✍️ Cara Tulis ke Shared Memory

### Daily Log (Selalu)
```bash
# Append ke log hari ini
echo "- [HH:MM] [agentN] Apa yang dikerjakan" >> /root/.openclaw/workspace/memory/$(date +%Y-%m-%d).md
```

### Long-term Memory (Jika Ada Yang Penting)
Edit `MEMORY.md` langsung — tambah di section yang relevan.

### Commit ke Git (Setelah Nulis)
```bash
cd /root/.openclaw/workspace
git add -A
git commit -m "[agentN] Session summary: ..."
```

---

## 🔄 Startup Sequence (Setiap Session)

1. `cat /root/.openclaw/workspace/health-state.json` — cek status
2. `cat /root/.openclaw/workspace/SOUL.md` — siapa kamu
3. `cat /root/.openclaw/workspace/USER.md` — siapa mas Aris
4. `cat /root/.openclaw/workspace/memory/$(date +%Y-%m-%d).md` — hari ini
5. Jika direct session: `cat /root/.openclaw/workspace/MEMORY.md`

---

## 🚦 Kolaborasi Antar Agent

Agent bisa spawn agent lain untuk bantu task spesifik (bukan hanya saat failover):

```
sessions_spawn dengan:
- task: "Deskripsi task"
- label: "agent2"  // atau agent3, agent4, agent5, dst.
```

Backup agent bisa di-spawn oleh primary untuk parallel work:
- Agent 1 spawn Agent 5 → paralel handle task monitoring sambil agent 1 fokus ke user
- Agent 2 spawn Agent 6 → minta alternatif konten
- Agent 3 spawn Agent 7 → cross-validate data
- Agent 4 spawn Agent 8 → code review

---

## 📝 Aturan Tulis Shared Memory

- **Jangan hapus** memory agent lain — append, jangan overwrite
- **Tag siapa yang nulis**: `[agent1]`, `[agent2]`, dst.
- **Commit setiap selesai** session yang meaningful
- `MEMORY.md` hanya untuk hal penting/long-term — bukan raw log
- Raw log masuk ke `memory/YYYY-MM-DD.md`
