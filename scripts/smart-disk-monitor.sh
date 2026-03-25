#!/bin/bash
# Smart disk monitor — alert via Telegram if disk usage critical
THRESHOLD=80
SCRIPT_DIR="$(dirname "$0")"

usage=$(df / | tail -1 | awk '{print $5}' | tr -d '%')
total=$(df -h / | tail -1 | awk '{print $2}')
used=$(df -h / | tail -1 | awk '{print $3}')
avail=$(df -h / | tail -1 | awk '{print $4}')

if [ "$usage" -ge "$THRESHOLD" ]; then
    echo "⚠️ DISK ALERT: ${usage}% used!"
    "$SCRIPT_DIR/telegram-send.sh" "" "⚠️ *DISK ALERT*
    
💾 Usage: ${usage}% (threshold: ${THRESHOLD}%)
📊 Total: ${total} | Used: ${used} | Free: ${avail}

Suggestion: Clear old logs, sessions, or /tmp files" 2>/dev/null
else
    echo "✅ Disk OK: ${usage}% (threshold: ${THRESHOLD}%)"
fi

# Check /tmp size
tmp_size=$(du -sh /tmp 2>/dev/null | awk '{print $1}')
echo "📂 /tmp size: $tmp_size"

# Check log sizes
big_logs=$(find /var/log /tmp /root/.openclaw/logs -name "*.log" -size +50M 2>/dev/null)
if [ -n "$big_logs" ]; then
    echo "⚠️ Big log files (>50MB):"
    echo "$big_logs" | while read f; do
        echo "  $(du -h "$f" | awk '{print $1}') $f"
    done
fi
