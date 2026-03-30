#!/bin/bash
# Generate foto dengan model picker Telegram
# Usage: generate-image.sh "<prompt>" "[caption]"
#
# Flow:
#   1. Tanya user via Telegram: mau pakai model apa?
#   2. Generate dengan model pilihan
#   3. Kalau gagal → tanya konfirmasi: mau coba fallback?
#   4. Kirim hasil ke Telegram

PROMPT="$1"
CAPTION="${2:-$1}"
CHAT_ID="${3:-613802669}"
MODEL_OVERRIDE="$4"
AUTH_FILE="/root/.openclaw/agents/agent1/agent/auth-profiles.json"
TG_SEND="/root/.openclaw/workspace/scripts/telegram-send.sh"

if [ -z "$PROMPT" ]; then
  echo "Usage: generate-image.sh <prompt> [caption] [chat_id] [model]" >&2
  exit 1
fi

GEMINI_KEY=$(python3 -c "import json; d=json.load(open('$AUTH_FILE')); print(d['profiles']['google:default']['key'])" 2>/dev/null)
KIE_KEY=$(python3 -c "import json; d=json.load(open('$AUTH_FILE')); print(d['profiles']['kieai:default']['key'])" 2>/dev/null)
OPENAI_KEY=$(python3 -c "import json; d=json.load(open('$AUTH_FILE')); print(d['profiles']['openai:default']['key'])" 2>/dev/null)

# ── Fungsi generate per model ──────────────────────────────────────────────

gen_gemini() {
  echo "[gen] Gemini Imagen..." >&2
  local OUT=/tmp/img-gemini-$(date +%s).png
  local RESP=$(curl -s -X POST \
    "https://generativelanguage.googleapis.com/v1beta/models/imagen-3.0-generate-002:predict?key=${GEMINI_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"instances\":[{\"prompt\":\"$PROMPT\"}],\"parameters\":{\"sampleCount\":1}}")
  echo "$RESP" | python3 -c "
import json,sys,base64
d=json.load(sys.stdin)
preds=d.get('predictions',[])
if preds:
    data=preds[0].get('bytesBase64Encoded','')
    if data:
        open('$OUT','wb').write(base64.b64decode(data))
        print('ok')
" 2>/dev/null
  [ -f "$OUT" ] && [ -s "$OUT" ] && echo "$OUT"
}

gen_kie_flux() {
  local MODEL="${1:-flux-kontext-pro}"  # flux-kontext-pro atau flux-kontext-max
  echo "[gen] kie.ai Flux Kontext ($MODEL)..." >&2
  local OUT=/tmp/img-flux-$(date +%s).jpg
  local RESP=$(curl -s -X POST "https://api.kie.ai/api/v1/flux/kontext/generate" \
    -H "Authorization: Bearer $KIE_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"prompt\":\"$PROMPT\",\"aspectRatio\":\"1:1\",\"model\":\"$MODEL\"}")
  local TASK=$(echo "$RESP" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('data',{}).get('taskId',''))" 2>/dev/null)
  [ -z "$TASK" ] && return 1
  for i in $(seq 1 15); do
    sleep 8
    local POLL=$(curl -s "https://api.kie.ai/api/v1/flux/kontext/record-info?taskId=$TASK" -H "Authorization: Bearer $KIE_KEY")
    local FLAG=$(echo "$POLL" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('data',{}).get('successFlag',''))" 2>/dev/null)
    local URL=$(echo "$POLL" | python3 -c "
import json,sys
d=json.load(sys.stdin)
r=(d.get('data') or {}).get('response') or {}
print(r.get('resultImageUrl','') or (r.get('imageList') or [''])[0])
" 2>/dev/null)
    [ "$FLAG" = "3" ] && return 1
    if [ -n "$URL" ]; then
      curl -s -L "$URL" -o "$OUT"
      [ -f "$OUT" ] && [ -s "$OUT" ] && echo "$OUT" && return 0
    fi
  done
  return 1
}

gen_kie_gpt4o() {
  echo "[gen] kie.ai GPT-4o Image..." >&2
  local OUT=/tmp/img-gpt4o-$(date +%s).png
  local RESP=$(curl -s -X POST "https://api.kie.ai/api/v1/gpt4o-image/generate" \
    -H "Authorization: Bearer $KIE_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"prompt\":\"$PROMPT\",\"size\":\"1:1\"}")
  local TASK=$(echo "$RESP" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('data',{}).get('taskId',''))" 2>/dev/null)
  [ -z "$TASK" ] && return 1
  for i in $(seq 1 15); do
    sleep 8
    local POLL=$(curl -s "https://api.kie.ai/api/v1/gpt4o-image/record-info?taskId=$TASK" -H "Authorization: Bearer $KIE_KEY")
    local URLS=$(echo "$POLL" | python3 -c "
import json,sys
d=json.load(sys.stdin)
r=(d.get('data') or {}).get('response') or {}
urls=r.get('resultUrls',[])
print(urls[0] if urls else '')
" 2>/dev/null)
    if [ -n "$URLS" ]; then
      curl -s -L "$URLS" -o "$OUT"
      [ -f "$OUT" ] && [ -s "$OUT" ] && echo "$OUT" && return 0
    fi
  done
  return 1
}

gen_kie_imagen4() {
  local MODEL="${1:-google/imagen4}"
  echo "[gen] kie.ai $MODEL..." >&2
  local OUT=/tmp/img-imagen4-$(date +%s).png
  local RESP=$(curl -s -X POST "https://api.kie.ai/api/v1/jobs/createTask" \
    -H "Authorization: Bearer $KIE_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$MODEL\",\"prompt\":\"$PROMPT\",\"output_format\":\"png\",\"image_size\":\"1:1\"}")
  local TASK=$(echo "$RESP" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('data',{}).get('taskId',''))" 2>/dev/null)
  [ -z "$TASK" ] && return 1
  for i in $(seq 1 18); do
    sleep 8
    local POLL=$(curl -s "https://api.kie.ai/api/v1/jobs/recordInfo?taskId=$TASK" -H "Authorization: Bearer $KIE_KEY")
    local STATUS=$(echo "$POLL" | python3 -c "import json,sys; d=json.load(sys.stdin); print((d.get('data') or {}).get('status',''))" 2>/dev/null)
    local URL=$(echo "$POLL" | python3 -c "
import json,sys
d=json.load(sys.stdin)
r=(d.get('data') or {}).get('response') or {}
imgs=r.get('images',[]) or r.get('resultUrls',[])
print(imgs[0].get('url','') if imgs and isinstance(imgs[0],dict) else (imgs[0] if imgs else ''))
" 2>/dev/null)
    [ "$STATUS" = "fail" ] && return 1
    if [ -n "$URL" ]; then
      curl -s -L "$URL" -o "$OUT"
      [ -f "$OUT" ] && [ -s "$OUT" ] && echo "$OUT" && return 0
    fi
  done
  return 1
}

gen_kie_seedream4() {
  echo "[gen] kie.ai Seedream 4.0..." >&2
  local OUT=/tmp/img-seedream-$(date +%s).png
  local RESP=$(curl -s -X POST "https://api.kie.ai/api/v1/jobs/createTask" \
    -H "Authorization: Bearer $KIE_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"bytedance/seedream-v4-text-to-image\",\"prompt\":\"$PROMPT\",\"image_size\":\"square_hd\"}")
  local TASK=$(echo "$RESP" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('data',{}).get('taskId',''))" 2>/dev/null)
  [ -z "$TASK" ] && return 1
  for i in $(seq 1 18); do
    sleep 8
    local POLL=$(curl -s "https://api.kie.ai/api/v1/jobs/recordInfo?taskId=$TASK" -H "Authorization: Bearer $KIE_KEY")
    local STATUS=$(echo "$POLL" | python3 -c "import json,sys; d=json.load(sys.stdin); print((d.get('data') or {}).get('status',''))" 2>/dev/null)
    local URL=$(echo "$POLL" | python3 -c "
import json,sys
d=json.load(sys.stdin)
r=(d.get('data') or {}).get('response') or {}
imgs=r.get('images',[]) or r.get('resultUrls',[])
print(imgs[0].get('url','') if imgs and isinstance(imgs[0],dict) else (imgs[0] if imgs else ''))
" 2>/dev/null)
    [ "$STATUS" = "fail" ] && return 1
    if [ -n "$URL" ]; then
      curl -s -L "$URL" -o "$OUT"
      [ -f "$OUT" ] && [ -s "$OUT" ] && echo "$OUT" && return 0
    fi
  done
  return 1
}

gen_gpt15() {
  echo "[gen] GPT-Image-1.5 (OpenAI)..." >&2
  local OUT=/tmp/img-gpt15-$(date +%s).png
  local RESP=$(curl -s -X POST "https://api.openai.com/v1/images/generations" \
    -H "Authorization: Bearer $OPENAI_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"gpt-image-1.5\",\"prompt\":\"$PROMPT\",\"size\":\"1024x1024\",\"quality\":\"medium\",\"n\":1}")
  echo "$RESP" | python3 -c "
import json,sys,base64
d=json.load(sys.stdin)
items=d.get('data',[])
if items:
    b64=items[0].get('b64_json','')
    url=items[0].get('url','')
    if b64:
        open('$OUT','wb').write(base64.b64decode(b64))
        print('ok')
    elif url:
        print(url)
" 2>/dev/null
  [ -f "$OUT" ] && [ -s "$OUT" ] && echo "$OUT"
}

# ── Map model code → fungsi generate ──────────────────────────────────────
run_model() {
  local CODE="$1"
  case "$CODE" in
    gemini)    gen_gemini ;;
    flux_pro)  gen_kie_flux "flux-kontext-pro" ;;
    flux_max)  gen_kie_flux "flux-kontext-max" ;;
    gpt4o)     gen_kie_gpt4o ;;
    imagen4)   gen_kie_imagen4 "google/imagen4" ;;
    imagen4u)  gen_kie_imagen4 "google/imagen4-ultra" ;;
    seedream4) gen_kie_seedream4 ;;
    gpt15)     gen_gpt15 ;;
    *)         gen_gemini ;;
  esac
}

# Label model untuk pesan konfirmasi
model_label() {
  case "$1" in
    gemini)    echo "Gemini Imagen (Google)" ;;
    flux_pro)  echo "Flux Kontext Pro (kie.ai)" ;;
    flux_max)  echo "Flux Kontext Max (kie.ai)" ;;
    gpt4o)     echo "GPT-4o Image (kie.ai)" ;;
    imagen4)   echo "Google Imagen 4 (kie.ai)" ;;
    imagen4u)  echo "Google Imagen 4 Ultra (kie.ai)" ;;
    seedream4) echo "Seedream 4.0 (kie.ai)" ;;
    gpt15)     echo "GPT-Image-1.5 (OpenAI)" ;;
    *)         echo "$1" ;;
  esac
}

# Fallback chain per model
fallback_of() {
  case "$1" in
    gemini)    echo "flux_pro" ;;
    flux_pro)  echo "flux_max" ;;
    flux_max)  echo "gpt4o" ;;
    gpt4o)     echo "imagen4" ;;
    imagen4)   echo "seedream4" ;;
    imagen4u)  echo "seedream4" ;;
    seedream4) echo "gpt15" ;;
    gpt15)     echo "" ;;
    *)         echo "gpt15" ;;
  esac
}

# ── MAIN ───────────────────────────────────────────────────────────────────

# 1. Pilih model — bypass picker (konflik getUpdates dgn gateway)
if [ -n "$MODEL_OVERRIDE" ]; then
  CHOSEN_MODEL="$MODEL_OVERRIDE"
  echo "[direct] Model: $CHOSEN_MODEL (bypass picker)" >&2
else
  CHOSEN_MODEL="gemini"
  echo "[default] Model: gemini (no picker — gateway conflict)" >&2
fi

# 2. Generate dengan model pilihan + auto-fallback
CURRENT_MODEL="$CHOSEN_MODEL"
while true; do
  LABEL=$(model_label "$CURRENT_MODEL")
  echo "[generate] Mencoba: $LABEL" >&2

  RESULT=$(run_model "$CURRENT_MODEL")

  if [ -n "$RESULT" ] && [ -f "$RESULT" ] && [ -s "$RESULT" ]; then
    # Sukses!
    $TG_SEND "$RESULT" "🖼 $CAPTION
_Model: $LABEL_" "$CHAT_ID"
    echo "IMAGE_SENT_OK"
    exit 0
  fi

  # Gagal — cari fallback
  NEXT=$(fallback_of "$CURRENT_MODEL")
  if [ -z "$NEXT" ]; then
    # Tidak ada fallback lagi
    BOT_TOKEN=$(python3 -c "import json; d=json.load(open('/root/.openclaw/openclaw.json')); print(d['channels']['telegram']['botToken'])" 2>/dev/null)
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
      -H "Content-Type: application/json" \
      -d "{\"chat_id\":\"$CHAT_ID\",\"text\":\"❌ Semua model gagal. Generate foto dibatalkan.\",\"parse_mode\":\"Markdown\"}" > /dev/null
    echo "ERROR: Semua model gagal" >&2
    exit 1
  fi

  # Auto-fallback tanpa confirm (picker konflik dgn gateway polling)
  NEXT_LABEL=$(model_label "$NEXT")
  echo "[fallback] $(model_label $CURRENT_MODEL) gagal → coba $NEXT_LABEL" >&2

  CURRENT_MODEL="$NEXT"
done
