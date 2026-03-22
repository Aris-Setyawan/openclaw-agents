#!/bin/bash
# Generate video via kie.ai Veo3 (primary) atau Google Veo (fallback)
# Default: kie.ai Veo3 Fast (cheaper, audio included)
# Usage: generate-video.sh "<prompt>" "[caption]" "[provider]" "[duration: 5-8]"
#
# Provider options:
#   kieai (default) - kie.ai Veo3 Fast, ~Rp 10-15K/video
#   google - Google Veo 3, ~Rp 18-23K/video (video + audio charged separately)

PROMPT="$1"
CAPTION="${2:-Video dari Veo}"
PROVIDER="${3:-kieai}"
DURATION="${4:-6}"

if [ -z "$PROMPT" ]; then
  echo "Usage: generate-video.sh <prompt> [caption] [provider: kieai|google] [duration 5-8]" >&2
  exit 1
fi

# ═══ MONITORING & RATE LIMIT ═══
/root/.openclaw/workspace/scripts/monitor-api-usage.sh "generate-video" "video" "$PROVIDER" 2>/dev/null || true

if [ "$DURATION" -lt 5 ] || [ "$DURATION" -gt 8 ]; then
  DURATION=6
fi

AUTH_FILE="/root/.openclaw/agents/agent1/agent/auth-profiles.json"
GEMINI_API_KEY=$(python3 -c "import json; d=json.load(open('$AUTH_FILE')); print(d['profiles']['google:default']['key'])" 2>/dev/null)
KIE_KEY=$(python3 -c "import json; d=json.load(open('$AUTH_FILE')); print(d['profiles']['kieai:default']['key'])" 2>/dev/null)

OUT=/tmp/video-$(date +%s).mp4

# ── PRIMARY: KIE.AI VEO 3 FAST ───────────────────────────────────────────────
kie_video_gen() {
  if [ -z "$KIE_KEY" ]; then
    echo "[kie.ai video] API key tidak ditemukan" >&2
    return 1
  fi

  echo "[kie.ai] Generating video via Veo3 Fast..." >&2
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
      curl -s -L "$VID_URL" -o "$OUT"
      if [ -f "$OUT" ] && [ -s "$OUT" ]; then
        /root/.openclaw/workspace/scripts/telegram-send.sh "$OUT" "$CAPTION"
        echo "VIDEO_SENT_OK"
        return 0
      fi
    fi
  done
  echo "[kie.ai veo] Timeout" >&2
  return 1
}

# ── ROUTING LOGIC ────────────────────────────────────────────────────────────
if [ "$PROVIDER" = "google" ]; then
  echo "[provider] Google Veo explicitly requested" >&2
  # Google Veo flow
  if [ -z "$GEMINI_API_KEY" ]; then
    echo "[google] No API key, fallback to kie.ai" >&2
    kie_video_gen || { echo "ERROR: Semua video gen gagal" >&2; exit 1; }
    exit 0
  fi
else
  # Default: kie.ai
  echo "[provider] Using kie.ai Veo3 Fast (default)" >&2
  kie_video_gen && exit 0
  echo "[fallback] kie.ai gagal, coba Google Veo..." >&2
  if [ -z "$GEMINI_API_KEY" ]; then
    echo "ERROR: Google Veo unavailable (no API key)" >&2
    exit 1
  fi
fi

# ── GOOGLE VEO (fallback atau explicit) ──────────────────────────────────────
BASE_URL="https://generativelanguage.googleapis.com/v1beta"
MODEL="${5:-veo-3.0-fast-generate-001}"

echo "[google veo] Model: $MODEL | Durasi: ${DURATION}s" >&2
echo "[google veo] Prompt: $PROMPT" >&2

# Submit Google Veo
RESPONSE=$(curl -s -X POST \
  "${BASE_URL}/models/${MODEL}:predictLongRunning?key=${GEMINI_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"instances\": [{\"prompt\": \"$PROMPT\"}],
    \"parameters\": {\"aspectRatio\": \"16:9\", \"durationSeconds\": $DURATION}
  }")

OPERATION=$(echo "$RESPONSE" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('name',''))" 2>/dev/null)

if [ -z "$OPERATION" ]; then
  echo "[google veo] ERROR: Gagal submit — $RESPONSE" >&2
  echo "ERROR: Google Veo gagal dan sudah mencoba kie.ai" >&2
  exit 1
fi

echo "[google veo] Operation: $OPERATION" >&2
echo "[google veo] Generating video, tunggu sebentar..." >&2

# Poll Google Veo
MAX_WAIT=300
WAITED=0

while [ $WAITED -lt $MAX_WAIT ]; do
  sleep 10
  WAITED=$((WAITED + 10))

  STATUS=$(curl -s "${BASE_URL}/${OPERATION}?key=${GEMINI_API_KEY}")
  DONE=$(echo "$STATUS" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('done','false'))" 2>/dev/null)
  echo "[google veo] ${WAITED}s — done=$DONE" >&2

  if [ "$DONE" = "True" ] || [ "$DONE" = "true" ]; then
    VIDEO_URI=$(echo "$STATUS" | python3 -c "
import json,sys
d=json.load(sys.stdin)
samples = d.get('response',{}).get('generateVideoResponse',{}).get('generatedSamples',[])
if samples:
    print(samples[0].get('video',{}).get('uri',''))
" 2>/dev/null)

    if [ -n "$VIDEO_URI" ]; then
      echo "[google veo] Downloading video..." >&2
      curl -s -L "${VIDEO_URI}&key=${GEMINI_API_KEY}" -o "$OUT"
    else
      echo "[google veo] ERROR: Tidak ada video URI" >&2
      exit 1
    fi

    if [ -f "$OUT" ] && [ -s "$OUT" ]; then
      /root/.openclaw/workspace/scripts/telegram-send.sh "$OUT" "$CAPTION"
      echo "VIDEO_SENT_OK"
      exit 0
    else
      echo "ERROR: File video tidak terbuat" >&2
      exit 1
    fi
  fi

  ERROR=$(echo "$STATUS" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('error',{}).get('message',''))" 2>/dev/null)
  if [ -n "$ERROR" ]; then
    echo "[google veo] ERROR: $ERROR" >&2
    exit 1
  fi
done

echo "ERROR: Google Veo timeout setelah ${MAX_WAIT}s" >&2
exit 1
