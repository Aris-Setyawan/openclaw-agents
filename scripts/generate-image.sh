#!/bin/bash
# Generate gambar + kirim ke Telegram
# Fallback chain: Gemini → kie.ai Flux Kontext → kie.ai Z-image → DALL-E
# Usage: generate-image.sh "<prompt>" "[caption]" "[ref_image_path]"

PROMPT="$1"
CAPTION="${2:-Gambar dari AI}"
REF_IMAGE="$3"

if [ -z "$PROMPT" ]; then
  echo "Usage: generate-image.sh <prompt> [caption] [ref_image_path]" >&2
  exit 1
fi

# ═══ MONITORING & RATE LIMIT ═══
/root/.openclaw/workspace/scripts/monitor-api-usage.sh "generate-image" "image" "attempting" 2>/dev/null || true

AUTH_FILE="/root/.openclaw/agents/agent1/agent/auth-profiles.json"
GEMINI_API_KEY=$(python3 -c "import json; d=json.load(open('$AUTH_FILE')); print(d['profiles']['google:default']['key'])" 2>/dev/null)
KIE_KEY=$(python3 -c "import json; d=json.load(open('$AUTH_FILE')); print(d['profiles']['kieai:default']['key'])" 2>/dev/null)

export GEMINI_API_KEY
export PATH="/root/.local/bin:/www/server/nvm/versions/node/v22.20.0/bin:$PATH"

SKILL=/www/server/nvm/versions/node/v22.20.0/lib/node_modules/openclaw/skills/nano-banana-pro
OUT=/tmp/img-$(date +%s).png

# ── 1. GEMINI (primary) ──────────────────────────────────────────────────────
if [ -n "$GEMINI_API_KEY" ]; then
  if [ -n "$REF_IMAGE" ] && [ -f "$REF_IMAGE" ]; then
    echo "[generate-image] Mode: image-to-image (ref: $REF_IMAGE)" >&2
    FULL_PROMPT="Edit ONLY the facial expression to: ${PROMPT}. Keep everything else EXACTLY the same: same person, same adult age, same body position, same pose, same clothes, same background, same lighting. Do NOT change age, do NOT change position, do NOT change body type."
    GEN_RESULT=$(uv run "$SKILL/scripts/generate_image.py" \
      --prompt "$FULL_PROMPT" \
      --input-image "$REF_IMAGE" \
      --filename "$OUT" 2>&1)
  else
    echo "[generate-image] Mode: text-to-image (Gemini)" >&2
    GEN_RESULT=$(uv run "$SKILL/scripts/generate_image.py" \
      --prompt "$PROMPT" \
      --filename "$OUT" \
      --resolution 1K 2>&1)
  fi
  echo "$GEN_RESULT" >&2

  if [ -f "$OUT" ] && [ -s "$OUT" ]; then
    /root/.openclaw/workspace/scripts/telegram-send.sh "$OUT" "$CAPTION"
    echo "IMAGE_SENT_OK"
    exit 0
  fi
  echo "[gemini] Gagal atau file kosong" >&2
else
  echo "[gemini] API key tidak ditemukan, skip" >&2
fi

# ── FALLBACK WARNING ────────────────────────────────────────────────────────
echo "" >&2
echo "⚠️  WARNING: Gemini Imagen failed or unavailable" >&2
echo "   Attempting fallback to kie.ai (may have different cost)" >&2
echo "" >&2

# Helper: poll kie.ai task sampai ada imageUrl (max 120s)
kie_poll() {
  local ENDPOINT="$1"
  local TASK_ID="$2"
  local WAITED=0
  while [ $WAITED -lt 120 ]; do
    sleep 8
    WAITED=$((WAITED + 8))
    STATUS=$(curl -s "${ENDPOINT}?taskId=${TASK_ID}" -H "Authorization: Bearer $KIE_KEY")
    IMG_URL=$(echo "$STATUS" | python3 -c "
import json,sys
d=json.load(sys.stdin)
data = d.get('data',{}) or {}
# Flux Kontext: response.resultImageUrl
r = data.get('response') or {}
url = r.get('resultImageUrl','') or r.get('imageUrl','')
# fallback: imageList array
if not url:
    imgs = r.get('imageList',[]) or data.get('imageUrls',[])
    url = imgs[0] if imgs else ''
print(url)
" 2>/dev/null)
    echo "[kie.ai] ${WAITED}s — ${IMG_URL:+found}" >&2
    if [ -n "$IMG_URL" ]; then
      echo "$IMG_URL"
      return 0
    fi
  done
  return 1
}

# ── 2. KIE.AI FLUX KONTEXT (fallback 1) ─────────────────────────────────────
if [ -n "$KIE_KEY" ]; then
  echo "[fallback-1] kie.ai Flux Kontext..." >&2
  KIE_RESP=$(curl -s -X POST "https://api.kie.ai/api/v1/flux/kontext/generate" \
    -H "Authorization: Bearer $KIE_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"prompt\": \"$PROMPT\", \"aspectRatio\": \"1:1\", \"model\": \"flux-kontext-pro\"}")

  KIE_TASK=$(echo "$KIE_RESP" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('data',{}).get('taskId',''))" 2>/dev/null)
  echo "[kie.ai flux] taskId: $KIE_TASK" >&2

  if [ -n "$KIE_TASK" ]; then
    KIE_OUT=/tmp/kieflux-$(date +%s).jpg
    IMG_URL=$(kie_poll "https://api.kie.ai/api/v1/flux/kontext/record-info" "$KIE_TASK")
    if [ -n "$IMG_URL" ]; then
      curl -s -L "$IMG_URL" -o "$KIE_OUT"
      if [ -f "$KIE_OUT" ] && [ -s "$KIE_OUT" ]; then
        /root/.openclaw/workspace/scripts/telegram-send.sh "$KIE_OUT" "$CAPTION"
        echo "IMAGE_SENT_OK"
        exit 0
      fi
    fi
  fi
  echo "[kie.ai flux] Gagal" >&2

  # ── 3. KIE.AI GPT-4O IMAGE (fallback 2) ─────────────────────────────────
  echo "[fallback-2] kie.ai GPT-4o Image..." >&2
  KIE_RESP2=$(curl -s -X POST "https://api.kie.ai/api/v1/gpt4o-image/generate" \
    -H "Authorization: Bearer $KIE_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"prompt\": \"$PROMPT\", \"size\": \"1:1\"}")

  KIE_TASK2=$(echo "$KIE_RESP2" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('data',{}).get('taskId',''))" 2>/dev/null)
  echo "[kie.ai gpt4o] taskId: $KIE_TASK2" >&2

  if [ -n "$KIE_TASK2" ]; then
    KIE_OUT2=/tmp/kiegpt4o-$(date +%s).png
    # Poll dengan endpoint spesifik gpt4o-image
    for j in $(seq 1 15); do
      sleep 8
      POLL2=$(curl -s "https://api.kie.ai/api/v1/gpt4o-image/record-info?taskId=$KIE_TASK2" \
        -H "Authorization: Bearer $KIE_KEY")
      IMG_URL2=$(echo "$POLL2" | python3 -c "
import json,sys
d=json.load(sys.stdin)
r = (d.get('data') or {}).get('response') or {}
urls = r.get('resultUrls',[])
print(urls[0] if urls else '')
" 2>/dev/null)
      echo "[kie.ai gpt4o] ${j} — ${IMG_URL2:+found}" >&2
      if [ -n "$IMG_URL2" ]; then
        curl -s -L "$IMG_URL2" -o "$KIE_OUT2"
        if [ -f "$KIE_OUT2" ] && [ -s "$KIE_OUT2" ]; then
          /root/.openclaw/workspace/scripts/telegram-send.sh "$KIE_OUT2" "$CAPTION"
          echo "IMAGE_SENT_OK"
          exit 0
        fi
      fi
    done
  fi
  echo "[kie.ai gpt4o] Gagal" >&2
fi

# ── 4. GPT-IMAGE-1.5 quality=medium (last resort) ───────────────────────────
echo "[fallback-3] gpt-image-1.5 (medium)..." >&2
OPENAI_KEY=$(python3 -c "import json; d=json.load(open('$AUTH_FILE')); print(d['profiles']['openai:default']['key'])" 2>/dev/null)

if [ -n "$OPENAI_KEY" ]; then
  GPT_RESP=$(curl -s -X POST "https://api.openai.com/v1/images/generations" \
    -H "Authorization: Bearer $OPENAI_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"gpt-image-1.5\",\"prompt\":\"$PROMPT\",\"size\":\"1024x1024\",\"quality\":\"medium\",\"n\":1}")

  GPT_B64=$(echo "$GPT_RESP" | python3 -c "
import json,sys
d=json.load(sys.stdin)
items = d.get('data',[])
if items:
    print(items[0].get('b64_json','') or items[0].get('url',''))
" 2>/dev/null)

  if [ -n "$GPT_B64" ]; then
    GPT_OUT=/tmp/gptimg-$(date +%s).png
    # Cek apakah URL atau base64
    if echo "$GPT_B64" | grep -q "^http"; then
      curl -s -L "$GPT_B64" -o "$GPT_OUT"
    else
      echo "$GPT_B64" | python3 -c "import base64,sys; open('$GPT_OUT','wb').write(base64.b64decode(sys.stdin.read().strip()))"
    fi
    if [ -f "$GPT_OUT" ] && [ -s "$GPT_OUT" ]; then
      /root/.openclaw/workspace/scripts/telegram-send.sh "$GPT_OUT" "$CAPTION"
      echo "IMAGE_SENT_OK"
      exit 0
    fi
  fi
  echo "[gpt-image-1.5] Gagal: $(echo "$GPT_RESP" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('error',{}).get('message','?'))" 2>/dev/null)" >&2
fi

echo "ERROR: Semua metode image gen gagal (Gemini → kie.ai Flux → kie.ai Z-image → gpt-image-1.5)" >&2
exit 1
