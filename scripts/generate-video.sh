#!/bin/bash
# Generate video via Google Veo + kirim ke Telegram
# Usage: generate-video.sh "<prompt>" "[caption]" "[duration: 5-8]" "[model]"
#
# Contoh:
#   generate-video.sh "wanita tersenyum di taman, sinematik" "Video Wulan 🎬"
#   generate-video.sh "kucing berlari" "caption" 8 veo-3.0-generate-001

PROMPT="$1"
CAPTION="${2:-Video dari Veo}"
DURATION="${3:-6}"
MODEL="${4:-veo-3.0-fast-generate-001}"

if [ -z "$PROMPT" ]; then
  echo "Usage: generate-video.sh <prompt> [caption] [duration 5-8] [model]" >&2
  exit 1
fi

# Validasi durasi
if [ "$DURATION" -lt 5 ] || [ "$DURATION" -gt 8 ]; then
  echo "[veo] Durasi harus 5-8 detik, pakai default 6" >&2
  DURATION=6
fi

# Ambil API key
GEMINI_API_KEY=$(python3 -c "import json; d=json.load(open('/root/.openclaw/agents/agent1/agent/auth-profiles.json')); print(d['profiles']['google:default']['key'])" 2>/dev/null)

if [ -z "$GEMINI_API_KEY" ]; then
  echo "ERROR: Tidak bisa baca GEMINI_API_KEY" >&2
  exit 1
fi

BASE_URL="https://generativelanguage.googleapis.com/v1beta"
OUT=/tmp/video-$(date +%s).mp4

echo "[veo] Model: $MODEL" >&2
echo "[veo] Prompt: $PROMPT" >&2
echo "[veo] Durasi: ${DURATION}s" >&2

# Step 1 — Submit generate request
echo "[veo] Submitting request..." >&2
RESPONSE=$(curl -s -X POST \
  "${BASE_URL}/models/${MODEL}:predictLongRunning?key=${GEMINI_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"instances\": [{\"prompt\": \"$PROMPT\"}],
    \"parameters\": {\"aspectRatio\": \"16:9\", \"durationSeconds\": $DURATION}
  }")

OPERATION=$(echo "$RESPONSE" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('name',''))" 2>/dev/null)

if [ -z "$OPERATION" ]; then
  echo "[veo] ERROR: Gagal submit — $RESPONSE" >&2
  exit 1
fi

echo "[veo] Operation: $OPERATION" >&2

# Step 2 — Poll sampai selesai (max 5 menit)
echo "[veo] Generating video, tunggu sebentar..." >&2
MAX_WAIT=300
WAITED=0
INTERVAL=10

while [ $WAITED -lt $MAX_WAIT ]; do
  sleep $INTERVAL
  WAITED=$((WAITED + INTERVAL))

  STATUS=$(curl -s "${BASE_URL}/${OPERATION}?key=${GEMINI_API_KEY}")
  DONE=$(echo "$STATUS" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('done','false'))" 2>/dev/null)

  echo "[veo] ${WAITED}s — done=$DONE" >&2

  if [ "$DONE" = "True" ] || [ "$DONE" = "true" ]; then
    # Ambil video URI dari response format Veo
    VIDEO_URI=$(echo "$STATUS" | python3 -c "
import json,sys
d=json.load(sys.stdin)
samples = d.get('response',{}).get('generateVideoResponse',{}).get('generatedSamples',[])
if samples:
    print(samples[0].get('video',{}).get('uri',''))
" 2>/dev/null)

    if [ -n "$VIDEO_URI" ]; then
      echo "[veo] Downloading video..." >&2
      curl -s -L "${VIDEO_URI}&key=${GEMINI_API_KEY}" -o "$OUT"
    else
      echo "[veo] ERROR: Tidak ada video URI di response" >&2
      echo "$STATUS" | python3 -c "import json,sys; print(json.dumps(json.load(sys.stdin).get('response',{}), indent=2))" >&2
      exit 1
    fi

    if [ -f "$OUT" ] && [ -s "$OUT" ]; then
      SIZE=$(ls -lh "$OUT" | awk '{print $5}')
      echo "[veo] Video saved: $OUT ($SIZE)" >&2
      /root/.openclaw/workspace/scripts/telegram-send.sh "$OUT" "$CAPTION"
      echo "$OUT"
      exit 0
    else
      echo "[veo] ERROR: File kosong atau tidak ada" >&2
      exit 1
    fi
  fi

  # Cek error
  ERROR=$(echo "$STATUS" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('error',{}).get('message',''))" 2>/dev/null)
  if [ -n "$ERROR" ]; then
    echo "[veo] ERROR: $ERROR" >&2
    exit 1
  fi
done

echo "[veo] TIMEOUT: Video tidak selesai dalam ${MAX_WAIT}s" >&2
exit 1
