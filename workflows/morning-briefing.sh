#!/bin/bash
# Morning briefing — cuaca, calendar, reminders, news summary
# Run daily at 7:00 AM WIB (00:00 UTC)

echo "🌅 Morning briefing — $(date '+%Y-%m-%d %H:%M')"

# 1. Weather
echo "1️⃣ Weather check..."
/root/.openclaw/workspace/scripts/send-weather.sh "Jakarta"

# 2. System status
echo "2️⃣ System status..."
openclaw status 2>&1 | grep -E "(gateway|agents|sessions)" | head -10

# 3. API balances
echo "3️⃣ API balances..."
/root/.openclaw/workspace/scripts/check-all-balances.sh 2>&1 | grep -v "^$" | head -20

# 4. Disk space
echo "4️⃣ Disk space..."
df -h / /root 2>/dev/null | grep -v "^Filesystem"

echo "✅ Morning briefing complete"
