#!/bin/bash
# Audit disk remote server dan kirim laporan ke Telegram
# Usage: check-disk-remote.sh [host] [user]

REMOTE_HOST="${1:-YOUR_REMOTE_SERVER_IP}"
REMOTE_USER="${2:-root}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519_remote}"
OPENCLAW_JSON="${OPENCLAW_JSON:-/root/.openclaw/openclaw.json}"
BOT_TOKEN=$(python3 -c "import json; d=json.load(open('$OPENCLAW_JSON')); print(d['channels']['telegram']['botToken'])")
CHAT_ID=$(python3 -c "import json; d=json.load(open('$OPENCLAW_JSON')); print(d['channels']['telegram']['allowFrom'][0])")

SSH="ssh -i $SSH_KEY -o StrictHostKeyChecking=no ${REMOTE_USER}@${REMOTE_HOST}"

# Ambil data dari remote server
DISK_INFO=$($SSH "df -h / 2>/dev/null")
HOSTNAME=$($SSH "hostname")
TOP_DIRS=$($SSH "du -sh /var/log /tmp /root /home /opt /var/www 2>/dev/null | sort -rh | head -8")
LARGE_FILES=$($SSH "find / -xdev -type f -size +100M 2>/dev/null | head -10 | xargs ls -lh 2>/dev/null | awk '{print \$5, \$9}'")
DOCKER_SIZE=$($SSH "docker system df 2>/dev/null | tail -5" 2>/dev/null || echo "Docker tidak terinstall")
LOG_SIZE=$($SSH "du -sh /var/log 2>/dev/null")

# Parse usage %
DISK_PCT=$($SSH "df / | tail -1 | awk '{print \$5}' | tr -d '%'")

# Alert emoji
if [ "$DISK_PCT" -ge 90 ] 2>/dev/null; then
  ALERT="🔴 KRITIS"
elif [ "$DISK_PCT" -ge 80 ] 2>/dev/null; then
  ALERT="🟠 PERINGATAN"
else
  ALERT="🟢 Normal"
fi

MSG="💾 <b>Disk Audit — ${HOSTNAME}</b> (${REMOTE_HOST})
📅 $(TZ=Asia/Jakarta date '+%d %B %Y • %H:%M WIB')

━━━━━━━━━━━━━━━━━━
📊 <b>OVERVIEW</b>
━━━━━━━━━━━━━━━━━━
$(echo "$DISK_INFO" | tail -1 | awk '{printf "Total: %s | Used: %s | Free: %s | %s", $2, $3, $4, $5}')
Status: ${ALERT} (${DISK_PCT}%)

━━━━━━━━━━━━━━━━━━
📁 <b>TOP DIREKTORI</b>
━━━━━━━━━━━━━━━━━━
<code>${TOP_DIRS}</code>

━━━━━━━━━━━━━━━━━━
🗂️ <b>FILE BESAR (&gt;100MB)</b>
━━━━━━━━━━━━━━━━━━
<code>${LARGE_FILES:-Tidak ada}</code>

━━━━━━━━━━━━━━━━━━
🐳 <b>DOCKER</b>
━━━━━━━━━━━━━━━━━━
<code>${DOCKER_SIZE}</code>

📜 Log size: ${LOG_SIZE}"

curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -d "chat_id=${CHAT_ID}" \
  --data-urlencode "text=${MSG}" \
  -d "parse_mode=HTML" > /dev/null

echo "✅ Disk audit ${HOSTNAME} terkirim ke Telegram"
