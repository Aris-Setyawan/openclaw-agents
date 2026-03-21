#!/bin/bash
# Generate gambar + kirim ke Telegram dalam satu command
# Usage: generate-image.sh "<prompt>" "[caption]"
# Output: path file yang di-generate

PROMPT="$1"
CAPTION="${2:-Gambar dari Gemini}"

if [ -z "$PROMPT" ]; then
  echo "Usage: generate-image.sh <prompt> [caption]" >&2
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

# Generate dengan Gemini
if uv run "$SKILL/scripts/generate_image.py" \
    --prompt "$PROMPT" \
    --filename "$OUT" \
    --resolution 1K 2>&1; then

  # Kirim ke Telegram
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
