#!/bin/bash
# Clear old sessions agent2 & agent3 untuk hemat token
# Dipanggil tiap 3 hari via cron

LOG="/root/.openclaw/workspace/logs/session-clear.log"
TS=$(date -u +"%Y-%m-%d %H:%M UTC")

for AGENT in agent2 agent3; do
  DIR="/root/.openclaw/agents/$AGENT/sessions"
  COUNT=$(ls "$DIR"/*.jsonl 2>/dev/null | wc -l)
  if [ "$COUNT" -gt 0 ]; then
    # Keep hanya 1 session terbaru, hapus sisanya
    LATEST=$(ls -t "$DIR"/*.jsonl 2>/dev/null | head -1)
    ls "$DIR"/*.jsonl 2>/dev/null | grep -v "$LATEST" | xargs rm -f 2>/dev/null
    REMOVED=$((COUNT - 1))
    echo "$TS | $AGENT | cleared $REMOVED old sessions" >> "$LOG"
    
    # Trim session terbaru: keep hanya 20 pesan terakhir
    if [ -f "$LATEST" ]; then
      LINES=$(wc -l < "$LATEST")
      if [ "$LINES" -gt 20 ]; then
        tail -20 "$LATEST" > "$LATEST.tmp" && mv "$LATEST.tmp" "$LATEST"
        echo "$TS | $AGENT | trimmed session to 20 lines (was $LINES)" >> "$LOG"
      fi
    fi
  fi
done

echo "$TS | session cleanup done" >> "$LOG"
