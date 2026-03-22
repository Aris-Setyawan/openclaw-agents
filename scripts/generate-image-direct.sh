#!/bin/bash
# LIGHTWEIGHT wrapper untuk image generation
# TIDAK melalui agent delegation, langsung eksekusi script
# Dipakai untuk hindari context bloat

PROMPT="$1"
CAPTION="${2:-Gambar dari AI}"
REF_IMAGE="$3"

# Langsung panggil script asli tanpa agent overhead
exec /root/.openclaw/workspace/scripts/generate-image.sh "$PROMPT" "$CAPTION" "$REF_IMAGE"
