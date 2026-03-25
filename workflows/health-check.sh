#!/bin/bash
# Health check — agents, services, disk, memory
# Run every 2 hours

echo "🩺 Health check — $(date '+%Y-%m-%d %H:%M')"

# 1. Agent status
echo "1️⃣ Agent health..."
cat /root/.openclaw/workspace/health-state.json 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for agent, info in data.get('agents', {}).items():
        status = info.get('status', 'unknown')
        print(f'  {agent}: {status}')
except:
    print('  No health-state.json')
"

# 2. Disk space
echo "2️⃣ Disk space..."
df -h / /root 2>/dev/null | tail -2

# 3. Memory usage
echo "3️⃣ Memory usage..."
free -h | grep -E "^Mem:" | awk '{print "  Total: "$2", Used: "$3", Free: "$4}'

# 4. Active sessions
echo "4️⃣ Active sessions..."
openclaw status 2>&1 | grep "sessions" | head -1

echo "✅ Health check complete"
