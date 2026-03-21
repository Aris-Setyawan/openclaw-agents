#!/bin/bash
# Generate gambar + kirim ke Telegram
# Usage: generate-image.sh "<prompt>" "[caption]" "[ref_image_path]"
#
# Jika ref_image_path disertakan → edit/compose dari gambar referensi (pertahankan wajah/pose)
# Jika tidak → text-to-image biasa

PROMPT="$1"
CAPTION="${2:-Gambar dari Gemini}"
REF_IMAGE="$3"

if [ -z "$PROMPT" ]; then
  echo "Usage: generate-image.sh <prompt> [caption] [ref_image_path]" >&2
  exit 1
fi

# Ambil key dari auth-profiles.json
GEMINI_API_KEY=$(python3 -c "import json; d=json.load(open('/root/.openclaw/agents/agent1/agent/auth-profiles.json')); print(d['profiles']['google:default']['key'])" 2>/dev/null)

if [ -z "$GEMINI_API_KEY" ]; then
  echo "ERROR: Tidak bisa baca GEMINI_API_KEY dari auth-profiles.json" >&2
  exit 1
fi

export GEMINI_API_KEY
export PATH="/root/.local/bin:/www/server/nvm/versions/node/v22.20.0/bin:$PATH"

SKILL=/www/server/nvm/versions/node/v22.20.0/lib/node_modules/openclaw/skills/nano-banana-pro
OUT=/tmp/img-$(date +%s).png

# Build command — pakai --input-image jika ada gambar referensi
if [ -n "$REF_IMAGE" ] && [ -f "$REF_IMAGE" ]; then
  echo "[generate-image] Pakai referensi: $REF_IMAGE" >&2
  # Wrap prompt dengan instruksi preserve — jangan ubah umur, pose, posisi, baju, background
  FULL_PROMPT="Edit ONLY the facial expression to: ${PROMPT}. Keep everything else EXACTLY the same: same person, same adult age, same body position, same pose, same clothes, same background, same lighting. Do NOT change age, do NOT change position, do NOT change body type."
  GEN_RESULT=$(uv run "$SKILL/scripts/generate_image.py" \
    --prompt "$FULL_PROMPT" \
    --input-image "$REF_IMAGE" \
    --filename "$OUT" 2>&1)
else
  echo "[generate-image] Text-to-image (no reference)" >&2
  GEN_RESULT=$(uv run "$SKILL/scripts/generate_image.py" \
    --prompt "$PROMPT" \
    --filename "$OUT" \
    --resolution 1K 2>&1)
fi

echo "$GEN_RESULT" >&2

if [ -f "$OUT" ]; then
  /root/.openclaw/workspace/scripts/telegram-send.sh "$OUT" "$CAPTION"
  echo "$OUT"
  exit 0
fi

# Fallback ke DALL-E jika Gemini gagal
echo "[fallback] Gemini gagal, coba DALL-E..." >&2
SKILL_DALLE=/www/server/nvm/versions/node/v22.20.0/lib/node_modules/openclaw/skills/openai-image-gen
OUT_DIR=/tmp/imgout-$(date +%s)
python3 "$SKILL_DALLE/scripts/gen.py" --prompt "$PROMPT" --model dall-e-3 --count 1 --out-dir "$OUT_DIR" 2>&1
DALLE_FILE=$(ls "$OUT_DIR"/*.png 2>/dev/null | head -1)

if [ -n "$DALLE_FILE" ]; then
  /root/.openclaw/workspace/scripts/telegram-send.sh "$DALLE_FILE" "$CAPTION"
  echo "$DALLE_FILE"
  exit 0
fi

echo "ERROR: Semua metode image gen gagal" >&2
exit 1
