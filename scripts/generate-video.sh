#!/bin/bash
# Generate video dengan model picker Telegram
# Usage: generate-video.sh "<prompt>" "[caption]"
#
# Flow:
#   1. Tanya user via Telegram: mau pakai model apa?
#   2. Generate dengan model pilihan
#   3. Kalau gagal → tanya konfirmasi: mau coba fallback?

PROMPT="$1"
CAPTION="${2:-Video AI}"
CHAT_ID="${3:-613802669}"
MODEL_OVERRIDE="$4"
AUTH_FILE="/root/.openclaw/agents/agent1/agent/auth-profiles.json"
TG_SEND="/root/.openclaw/workspace/scripts/telegram-send.sh"

if [ -z "$PROMPT" ]; then
  echo "Usage: generate-video.sh <prompt> [caption] [chat_id] [model]" >&2
  echo "Models: veo3f veo3q runway kling3 sora2 hailuo wan gveo" >&2
  exit 1
fi

KIE_KEY=$(python3 -c "import json; d=json.load(open('$AUTH_FILE')); print(d['profiles']['kieai:default']['key'])" 2>/dev/null)
GEMINI_KEY=$(python3 -c "import json; d=json.load(open('$AUTH_FILE')); print(d['profiles']['google:default']['key'])" 2>/dev/null)
OUT=/tmp/video-$(date +%s).mp4

# ── Fungsi polling umum (kie.ai /jobs/recordInfo) ─────────────────────────
poll_jobs() {
  local TASK="$1"
  local MAX="${2:-300}"
  local WAITED=0
  while [ $WAITED -lt $MAX ]; do
    sleep 12
    WAITED=$((WAITED + 12))
    local POLL=$(curl -s "https://api.kie.ai/api/v1/jobs/recordInfo?taskId=$TASK" -H "Authorization: Bearer $KIE_KEY")
    local STATUS=$(echo "$POLL" | python3 -c "import json,sys; d=json.load(sys.stdin); print((d.get('data') or {}).get('status',''))" 2>/dev/null)
    local URL=$(echo "$POLL" | python3 -c "
import json,sys
d=json.load(sys.stdin)
r=(d.get('data') or {}).get('response') or {}
print(r.get('videoUrl','') or r.get('video_url','') or (r.get('videos') or [{}])[0].get('url',''))
" 2>/dev/null)
    echo "[poll] ${WAITED}s status=$STATUS" >&2
    [ "$STATUS" = "fail" ] && return 1
    if [ -n "$URL" ]; then echo "$URL"; return 0; fi
  done
  return 1
}

# ── Fungsi generate per model ──────────────────────────────────────────────

gen_veo3f() {
  echo "[gen] kie.ai Veo3 Fast..." >&2
  local RESP=$(curl -s -X POST "https://api.kie.ai/api/v1/veo/generate" \
    -H "Authorization: Bearer $KIE_KEY" -H "Content-Type: application/json" \
    -d "{\"prompt\":\"$PROMPT\",\"model\":\"veo3_fast\",\"aspect_ratio\":\"16:9\"}")
  local TASK=$(echo "$RESP" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('data',{}).get('taskId',''))" 2>/dev/null)
  [ -z "$TASK" ] && return 1
  local WAITED=0
  while [ $WAITED -lt 300 ]; do
    sleep 15; WAITED=$((WAITED+15))
    local POLL=$(curl -s "https://api.kie.ai/api/v1/veo/record-info?taskId=$TASK" -H "Authorization: Bearer $KIE_KEY")
    local URL=$(echo "$POLL" | python3 -c "import json,sys; d=json.load(sys.stdin); print((d.get('data') or {}).get('videoUrl',''))" 2>/dev/null)
    echo "[veo3f] ${WAITED}s" >&2
    if [ -n "$URL" ]; then curl -s -L "$URL" -o "$OUT"; [ -s "$OUT" ] && echo "$OUT" && return 0; fi
  done
  return 1
}

gen_veo3q() {
  echo "[gen] kie.ai Veo3 Quality..." >&2
  local RESP=$(curl -s -X POST "https://api.kie.ai/api/v1/veo/generate" \
    -H "Authorization: Bearer $KIE_KEY" -H "Content-Type: application/json" \
    -d "{\"prompt\":\"$PROMPT\",\"model\":\"veo3\",\"aspect_ratio\":\"16:9\"}")
  local TASK=$(echo "$RESP" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('data',{}).get('taskId',''))" 2>/dev/null)
  [ -z "$TASK" ] && return 1
  local WAITED=0
  while [ $WAITED -lt 360 ]; do
    sleep 15; WAITED=$((WAITED+15))
    local POLL=$(curl -s "https://api.kie.ai/api/v1/veo/record-info?taskId=$TASK" -H "Authorization: Bearer $KIE_KEY")
    local URL=$(echo "$POLL" | python3 -c "import json,sys; d=json.load(sys.stdin); print((d.get('data') or {}).get('videoUrl',''))" 2>/dev/null)
    echo "[veo3q] ${WAITED}s" >&2
    if [ -n "$URL" ]; then curl -s -L "$URL" -o "$OUT"; [ -s "$OUT" ] && echo "$OUT" && return 0; fi
  done
  return 1
}

gen_runway() {
  echo "[gen] kie.ai Runway Gen4 Turbo..." >&2
  local RESP=$(curl -s -X POST "https://api.kie.ai/api/v1/runway/generate" \
    -H "Authorization: Bearer $KIE_KEY" -H "Content-Type: application/json" \
    -d "{\"prompt\":\"$PROMPT\",\"duration\":5,\"quality\":\"720p\",\"aspectRatio\":\"16:9\",\"callBackUrl\":\"https://example.com/cb\"}")
  local TASK=$(echo "$RESP" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('data',{}).get('taskId',''))" 2>/dev/null)
  [ -z "$TASK" ] && return 1
  local WAITED=0
  while [ $WAITED -lt 300 ]; do
    sleep 12; WAITED=$((WAITED+12))
    local POLL=$(curl -s "https://api.kie.ai/api/v1/runway/record-detail?taskId=$TASK" -H "Authorization: Bearer $KIE_KEY")
    local URL=$(echo "$POLL" | python3 -c "
import json,sys; d=json.load(sys.stdin)
r=(d.get('data') or {}).get('response') or {}
print(r.get('videoUrl','') or r.get('video_url',''))
" 2>/dev/null)
    echo "[runway] ${WAITED}s" >&2
    if [ -n "$URL" ]; then curl -s -L "$URL" -o "$OUT"; [ -s "$OUT" ] && echo "$OUT" && return 0; fi
  done
  return 1
}

gen_kling3() {
  echo "[gen] kie.ai Kling 3.0..." >&2
  local RESP=$(curl -s -X POST "https://api.kie.ai/api/v1/jobs/createTask" \
    -H "Authorization: Bearer $KIE_KEY" -H "Content-Type: application/json" \
    -d "{\"model\":\"kling-3.0/video\",\"prompt\":\"$PROMPT\",\"duration\":5,\"aspect_ratio\":\"16:9\",\"mode\":\"std\"}")
  local TASK=$(echo "$RESP" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('data',{}).get('taskId',''))" 2>/dev/null)
  [ -z "$TASK" ] && return 1
  local URL=$(poll_jobs "$TASK" 300)
  [ -z "$URL" ] && return 1
  curl -s -L "$URL" -o "$OUT"; [ -s "$OUT" ] && echo "$OUT"
}

gen_sora2() {
  echo "[gen] kie.ai Sora 2..." >&2
  local RESP=$(curl -s -X POST "https://api.kie.ai/api/v1/jobs/createTask" \
    -H "Authorization: Bearer $KIE_KEY" -H "Content-Type: application/json" \
    -d "{\"model\":\"sora-2-text-to-video\",\"prompt\":\"$PROMPT\",\"aspect_ratio\":\"landscape\",\"n_frames\":10}")
  local TASK=$(echo "$RESP" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('data',{}).get('taskId',''))" 2>/dev/null)
  [ -z "$TASK" ] && return 1
  local URL=$(poll_jobs "$TASK" 360)
  [ -z "$URL" ] && return 1
  curl -s -L "$URL" -o "$OUT"; [ -s "$OUT" ] && echo "$OUT"
}

gen_hailuo() {
  echo "[gen] kie.ai Hailuo Standard..." >&2
  local RESP=$(curl -s -X POST "https://api.kie.ai/api/v1/jobs/createTask" \
    -H "Authorization: Bearer $KIE_KEY" -H "Content-Type: application/json" \
    -d "{\"model\":\"hailuo/02-text-to-video-standard\",\"prompt\":\"$PROMPT\",\"duration\":6}")
  local TASK=$(echo "$RESP" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('data',{}).get('taskId',''))" 2>/dev/null)
  [ -z "$TASK" ] && return 1
  local URL=$(poll_jobs "$TASK" 300)
  [ -z "$URL" ] && return 1
  curl -s -L "$URL" -o "$OUT"; [ -s "$OUT" ] && echo "$OUT"
}

gen_wan() {
  echo "[gen] kie.ai Wan (Alibaba)..." >&2
  local RESP=$(curl -s -X POST "https://api.kie.ai/api/v1/jobs/createTask" \
    -H "Authorization: Bearer $KIE_KEY" -H "Content-Type: application/json" \
    -d "{\"model\":\"wan/text-to-video\",\"prompt\":\"$PROMPT\",\"aspect_ratio\":\"16:9\",\"duration\":5}")
  local TASK=$(echo "$RESP" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('data',{}).get('taskId',''))" 2>/dev/null)
  [ -z "$TASK" ] && return 1
  local URL=$(poll_jobs "$TASK" 300)
  [ -z "$URL" ] && return 1
  curl -s -L "$URL" -o "$OUT"; [ -s "$OUT" ] && echo "$OUT"
}

gen_gveo() {
  echo "[gen] Google Veo (direct)..." >&2
  local BASE="https://generativelanguage.googleapis.com/v1beta"
  local MODEL="veo-3.0-fast-generate-001"
  local RESP=$(curl -s -X POST "${BASE}/models/${MODEL}:predictLongRunning?key=${GEMINI_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"instances\":[{\"prompt\":\"$PROMPT\"}],\"parameters\":{\"aspectRatio\":\"16:9\",\"durationSeconds\":6}}")
  local OP=$(echo "$RESP" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('name',''))" 2>/dev/null)
  [ -z "$OP" ] && return 1
  local WAITED=0
  while [ $WAITED -lt 300 ]; do
    sleep 12; WAITED=$((WAITED+12))
    local STATUS=$(curl -s "${BASE}/${OP}?key=${GEMINI_KEY}")
    local DONE=$(echo "$STATUS" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('done','false'))" 2>/dev/null)
    echo "[gveo] ${WAITED}s done=$DONE" >&2
    if [ "$DONE" = "True" ] || [ "$DONE" = "true" ]; then
      local URL=$(echo "$STATUS" | python3 -c "
import json,sys; d=json.load(sys.stdin)
s=d.get('response',{}).get('generateVideoResponse',{}).get('generatedSamples',[])
print(s[0].get('video',{}).get('uri','') if s else '')
" 2>/dev/null)
      [ -z "$URL" ] && return 1
      curl -s -L "${URL}&key=${GEMINI_KEY}" -o "$OUT"
      [ -s "$OUT" ] && echo "$OUT" && return 0
    fi
  done
  return 1
}

# ── Map model code → fungsi ────────────────────────────────────────────────
run_model() {
  case "$1" in
    veo3f)  gen_veo3f ;;
    veo3q)  gen_veo3q ;;
    runway) gen_runway ;;
    kling3) gen_kling3 ;;
    sora2)  gen_sora2 ;;
    hailuo) gen_hailuo ;;
    wan)    gen_wan ;;
    gveo)   gen_gveo ;;
    *)      gen_veo3f ;;
  esac
}

model_label() {
  case "$1" in
    veo3f)  echo "Veo3 Fast (kie.ai)" ;;
    veo3q)  echo "Veo3 Quality (kie.ai)" ;;
    runway) echo "Runway Gen4 Turbo (kie.ai)" ;;
    kling3) echo "Kling 3.0 (kie.ai)" ;;
    sora2)  echo "Sora 2 (kie.ai)" ;;
    hailuo) echo "Hailuo Standard (kie.ai)" ;;
    wan)    echo "Wan/Alibaba (kie.ai)" ;;
    gveo)   echo "Google Veo (direct)" ;;
    *)      echo "$1" ;;
  esac
}

fallback_of() {
  # Google Veo first (gratis), kie.ai models terakhir (berbayar per attempt!)
  case "$1" in
    gveo)   echo "veo3f" ;;
    veo3f)  echo "veo3q" ;;
    veo3q)  echo "runway" ;;
    runway) echo "kling3" ;;
    kling3) echo "sora2" ;;
    sora2)  echo "hailuo" ;;
    hailuo) echo "wan" ;;
    wan)    echo "" ;;
    *)      echo "gveo" ;;
  esac
}

# ── MAIN ───────────────────────────────────────────────────────────────────
# Bypass picker jika model sudah di-specify (mencegah konflik getUpdates dgn gateway)
if [ -n "$MODEL_OVERRIDE" ]; then
  CHOSEN_MODEL="$MODEL_OVERRIDE"
  echo "[direct] Model: $CHOSEN_MODEL (bypass picker)" >&2
else
  # Default: Google Veo (gratis). kie.ai models berbayar per attempt!
  CHOSEN_MODEL="gveo"
  echo "[default] Model: gveo — Google Veo (gratis, bypass kie.ai)" >&2
fi

CURRENT_MODEL="$CHOSEN_MODEL"
while true; do
  LABEL=$(model_label "$CURRENT_MODEL")
  echo "[generate] Mencoba: $LABEL" >&2

  RESULT=$(run_model "$CURRENT_MODEL")

  if [ -n "$RESULT" ] && [ -f "$RESULT" ] && [ -s "$RESULT" ]; then
    $TG_SEND "$RESULT" "🎬 $CAPTION
_Model: $LABEL_" "$CHAT_ID"
    echo "VIDEO_SENT_OK"
    exit 0
  fi

  NEXT=$(fallback_of "$CURRENT_MODEL")
  if [ -z "$NEXT" ]; then
    BOT_TOKEN=$(python3 -c "import json; d=json.load(open('/root/.openclaw/openclaw.json')); print(d['channels']['telegram']['botToken'])" 2>/dev/null)
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
      -H "Content-Type: application/json" \
      -d "{\"chat_id\":\"$CHAT_ID\",\"text\":\"❌ Semua model gagal. Generate video dibatalkan.\"}" > /dev/null
    echo "ERROR: Semua model gagal" >&2
    exit 1
  fi

  # Auto-fallback tanpa confirm (picker konflik dgn gateway polling)
  NEXT_LABEL=$(model_label "$NEXT")
  echo "[fallback] $(model_label $CURRENT_MODEL) gagal → coba $NEXT_LABEL" >&2

  CURRENT_MODEL="$NEXT"
done
