#!/bin/bash
# openai-tts.sh - Text-to-Speech menggunakan OpenAI TTS API
# Mengambil API key dari auth-profiles.json, bukan hardcoded

set -euo pipefail

# --- Config ---
AUTH_FILE="/root/.openclaw/agents/agent1/agent/auth-profiles.json"
OPENAI_KEY=$(python3 -c "import json; d=json.load(open('$AUTH_FILE')); print(d['profiles']['openai:default']['key'])" 2>/dev/null)
if [ -z "$OPENAI_KEY" ]; then
  echo "ERROR: OpenAI API key not found in $AUTH_FILE" >&2
  exit 1
fi

# --- Functions ---
usage() {
  echo "Usage: $0 \"text to speak\" [--voice nova|alloy|echo|fable|onyx|shimmer] [--speed 0.8-1.2] [--send]"
  echo "  --voice : Voice model (default: nova)"
  echo "  --speed : Speaking speed (default: 1.0)"
  echo "  --send  : Send audio to Telegram after generation"
  exit 1
}

# --- Parse arguments ---
TEXT=""
VOICE="nova"
SPEED="1.0"
SEND=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --voice) VOICE="$2"; shift 2 ;;
    --speed) SPEED="$2"; shift 2 ;;
    --send) SEND=true; shift ;;
    --help) usage ;;
    *) 
      if [ -z "$TEXT" ]; then
        TEXT="$1"
      else
        TEXT="$TEXT $1"
      fi
      shift
      ;;
  esac
done

if [ -z "$TEXT" ]; then
  usage
fi

# --- Generate audio ---
echo "Generating TTS: \"$TEXT\" (voice: $VOICE, speed: $SPEED)"

OUTPUT_FILE="/tmp/tts_$(date +%s).mp3"
curl -s -X POST "https://api.openai.com/v1/audio/speech" \
  -H "Authorization: Bearer $OPENAI_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"tts-1\",
    \"input\": \"$TEXT\",
    \"voice\": \"$VOICE\",
    \"speed\": $SPEED
  }" \
  --output "$OUTPUT_FILE"

if [ $? -ne 0 ] || [ ! -s "$OUTPUT_FILE" ]; then
  echo "ERROR: TTS generation failed" >&2
  rm -f "$OUTPUT_FILE"
  exit 1
fi

echo "✅ Audio saved: $OUTPUT_FILE ($(stat -c%s "$OUTPUT_FILE") bytes)"

# --- Send to Telegram if requested ---
if [ "$SEND" = true ]; then
  if [ -f "/root/.openclaw/workspace/scripts/telegram-send.sh" ]; then
    /root/.openclaw/workspace/scripts/telegram-send.sh "$OUTPUT_FILE" "TTS: $(echo "$TEXT" | cut -c1-50)..."
  else
    echo "WARNING: telegram-send.sh not found, audio not sent"
  fi
fi

echo "✅ Done"
