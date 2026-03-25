#!/bin/bash
# Morning briefing — comprehensive daily summary
# Run daily at 7:00 AM WIB (00:00 UTC)
SCRIPT_DIR="/root/.openclaw/workspace/scripts"
TGSEND="$SCRIPT_DIR/telegram-send.sh"

echo "🌅 Morning Briefing — $(date '+%A, %d %B %Y')"
echo "================================================"

# Collect all info
REPORT=""

# 1. Weather
echo "1️⃣ Weather..."
weather=$(curl -s "wttr.in/Jakarta?format=%C+%t+%h+%w" 2>/dev/null)
REPORT="🌅 *Morning Briefing*\n$(date '+%A, %d %B %Y')\n\n"
REPORT+="☀️ *Cuaca Jakarta:* $weather\n\n"

# 2. System Status
echo "2️⃣ System status..."
uptime_info=$(uptime -p)
disk_usage=$(df -h / | tail -1 | awk '{print $5 " used (" $4 " free)"}')
mem_info=$(free -h | grep Mem | awk '{print $3 "/" $2 " (" int($3/$2*100) "%)"}')
REPORT+="🖥️ *System:*\n"
REPORT+="  • Uptime: $uptime_info\n"
REPORT+="  • Disk: $disk_usage\n"
REPORT+="  • RAM: $mem_info\n\n"

# 3. Agent Health
echo "3️⃣ Agent health..."
agent_status=$(python3 -c "
import json
with open('/root/.openclaw/workspace/health-state.json') as f:
    data = json.load(f)
healthy = sum(1 for a in data.get('agents',{}).values() if a.get('status')=='healthy')
total = len(data.get('agents',{}))
print(f'{healthy}/{total} healthy')
" 2>/dev/null || echo "unknown")
REPORT+="🤖 *Agents:* $agent_status\n\n"

# 4. GitHub
echo "4️⃣ GitHub..."
notif_count=$(gh api notifications --jq 'length' 2>/dev/null || echo "0")
REPORT+="🐙 *GitHub:* $notif_count notifications\n\n"

# 5. IPTV
echo "5️⃣ IPTV..."
ffmpeg_count=$(pgrep -c ffmpeg 2>/dev/null || echo "0")
web_status=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost/" 2>/dev/null)
REPORT+="📺 *IPTV:* FFmpeg=$ffmpeg_count, Web=HTTP $web_status\n\n"

# 6. API Balances
echo "6️⃣ API balances..."
REPORT+="💰 *API Balances:* Run check-all-balances.sh for details\n"

# Send to Telegram
echo ""
echo "$REPORT"
"$TGSEND" "" "$REPORT" 2>/dev/null

echo "✅ Morning briefing sent!"
