#!/bin/bash
# Kirim file/gambar ke Telegram
# Usage: telegram-send.sh <file_path> [caption] [chat_id]

FILE="$1"
CAPTION="${2:-}"
CHAT_ID="${3:-613802669}"

BOT_TOKEN=$(python3 -c "import json; d=json.load(open('/root/.openclaw/openclaw.json')); print(d['channels']['telegram']['botToken'])")

if [ ! -f "$FILE" ]; then
  echo "Error: file tidak ditemukan: $FILE"
  exit 1
fi

MIME=$(file --mime-type -b "$FILE")

if [[ "$MIME" == image/* ]]; then
  RESULT=$(curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendPhoto" \
    -F "chat_id=${CHAT_ID}" \
    -F "photo=@${FILE}" \
    -F "caption=${CAPTION}")
else
  RESULT=$(curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument" \
    -F "chat_id=${CHAT_ID}" \
    -F "document=@${FILE}" \
    -F "caption=${CAPTION}")
fi

OK=$(echo "$RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); print('ok' if d.get('ok') else d.get('description','error'))")
echo "$OK"
