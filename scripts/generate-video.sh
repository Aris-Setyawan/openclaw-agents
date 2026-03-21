#!/bin/bash
# Generate video via Google Veo + kirim ke Telegram
# Fallback: Google Veo → kie.ai Veo3 Fast
# Usage: generate-video.sh "<prompt>" "[caption]" "[duration: 5-8]" "[model]"

PROMPT="$1"
CAPTION="${2:-Video dari Veo}"
DURATION="${3:-6}"
MODEL="${4:-veo-3.0-fast-generate-001}"

if [ -z "$PROMPT" ]; then
  echo "Usage: generate-video.sh <prompt> [caption] [duration 5-8] [model]" >&2
  exit 1
fi

if [ "$DURATION" -lt 5 ] || [ "$DURATION" -gt 8 ]; then
  DURATION=6
fi

AUTH_FILE="/root/.openclaw/agents/agent1/agent/auth-profiles.json"
GEMINI_API_KEY=$(python3 -c "import json; d=json.load(open('$AUTH_FILE')); print(d['profiles']['google:default']['key'])" 2>/dev/null)
KIE_KEY=$(python3 -c "import json; d=json.load(open('$AUTH_FILE')); print(d['profiles']['kieai:default']['key'])" 2>/dev/null)

# ── FALLBACK: KIE.AI VEO 3 ───────────────────────────────────────────────────
kie_video_fallback() {
  if [ -z "$KIE_KEY" ]; then
    echo "[kie.ai video] API key tidak ditemukan" >&2
    return 1
  fi

  echo "[fallback] Google Veo gagal, coba kie.ai Veo3 Fast..." >&2
  KIE_RESP=$(curl -s -X POST "https://api.kie.ai/api/v1/veo/generate" \
    -H "Authorization: Bearer $KIE_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"prompt\": \"$PROMPT\", \"model\": \"veo3_fast\", \"aspect_ratio\": \"16:9\"}")

  KIE_TASK=$(echo "$KIE_RESP" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('data',{}).get('taskId',''))" 2>/dev/null)
  echo "[kie.ai veo] taskId: $KIE_TASK" >&2

  if [ -z "$KIE_TASK" ]; then
    echo "[kie.ai veo] Gagal submit: $KIE_RESP" >&2
    return 1
  fi

  # Poll max 5 menit
  KIE_WAITED=0
  KIE_VID_OUT=/tmp/kievid-$(date +%s).mp4
  while [ $KIE_WAITED -lt 300 ]; do
    sleep 15
    KIE_WAITED=$((KIE_WAITED + 15))
    STATUS=$(curl -s "https://api.kie.ai/api/v1/veo/record-info?taskId=$KIE_TASK" \
      -H "Authorization: Bearer $KIE_KEY")
    VID_URL=$(echo "$STATUS" | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(d.get('data',{}).get('videoUrl',''))
" 2>/dev/null)
    echo "[kie.ai veo] ${KIE_WAITED}s — ${VID_URL:+found}" >&2
    if [ -n "$VID_URL" ]; then
      curl -s -L "$VID_URL" -o "$KIE_VID_OUT"
      if [ -f "$KIE_VID_OUT" ] && [ -s "$KIE_VID_OUT" ]; then
        /root/.openclaw/workspace/scripts/telegram-send.sh "$KIE_VID_OUT" "$CAPTION"
        echo "VIDEO_SENT_OK"
        return 0
      fi
    fi
  done
  echo "[kie.ai veo] Timeout" >&2
  return 1
}

# ── 1. GOOGLE VEO (primary) ──────────────────────────────────────────────────
if [ -z "$GEMINI_API_KEY" ]; then
  echo "[veo] Tidak ada GEMINI_API_KEY, langsung ke fallback" >&2
  kie_video_fallback || { echo "ERROR: Semua video gen gagal" >&2; exit 1; }
  exit 0
fi

BASE_URL="https://generativelanguage.googleapis.com/v1beta"
OUT=/tmp/video-$(date +%s).mp4

echo "[veo] Model: $MODEL | Durasi: ${DURATION}s" >&2
echo "[veo] Prompt: $PROMPT" >&2

# Submit
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
  kie_video_fallback || { echo "ERROR: Semua video gen gagal" >&2; exit 1; }
  exit 0
fi

echo "[veo] Operation: $OPERATION" >&2
echo "[veo] Generating video, tunggu sebentar..." >&2

# Poll
MAX_WAIT=300
WAITED=0
VEO_FAILED=false

while [ $WAITED -lt $MAX_WAIT ]; do
  sleep 10
  WAITED=$((WAITED + 10))

  STATUS=$(curl -s "${BASE_URL}/${OPERATION}?key=${GEMINI_API_KEY}")
  DONE=$(echo "$STATUS" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('done','false'))" 2>/dev/null)
  echo "[veo] ${WAITED}s — done=$DONE" >&2

  if [ "$DONE" = "True" ] || [ "$DONE" = "true" ]; then
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
      echo "[veo] ERROR: Tidak ada video URI" >&2
      VEO_FAILED=true
      break
    fi

    if [ -f "$OUT" ] && [ -s "$OUT" ]; then
      /root/.openclaw/workspace/scripts/telegram-send.sh "$OUT" "$CAPTION"
      echo "VIDEO_SENT_OK"
      exit 0
    else
      VEO_FAILED=true
      break
    fi
  fi

  ERROR=$(echo "$STATUS" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('error',{}).get('message',''))" 2>/dev/null)
  if [ -n "$ERROR" ]; then
    echo "[veo] ERROR: $ERROR" >&2
    VEO_FAILED=true
    break
  fi
done

# Timeout atau error → coba kie.ai
kie_video_fallback || { echo "ERROR: Semua video gen gagal (Google Veo → kie.ai Veo3)" >&2; exit 1; }
