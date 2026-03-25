#!/bin/bash
# Check IPTV service health
IPTV_DIR="/www/wwwroot/iptv.lingkungantiga.network"
SCRIPT_DIR="$(dirname "$0")"

echo "📺 IPTV Health — $(date '+%Y-%m-%d %H:%M')"

# Check if PHP crons are running
ffmpeg_running=$(pgrep -c ffmpeg 2>/dev/null || echo "0")
echo "🎬 FFmpeg processes: $ffmpeg_running"

# Check recent logs
if [ -f "$IPTV_DIR/logs/ffmpeg-cron.log" ]; then
    last_log=$(tail -1 "$IPTV_DIR/logs/ffmpeg-cron.log" 2>/dev/null)
    echo "📋 Last ffmpeg log: $last_log"
fi

# Check disk usage of IPTV dir
iptv_size=$(du -sh "$IPTV_DIR" 2>/dev/null | awk '{print $1}')
echo "💾 IPTV dir size: $iptv_size"

# Check if site is responding
status=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost/" 2>/dev/null)
echo "🌐 Web status: HTTP $status"
