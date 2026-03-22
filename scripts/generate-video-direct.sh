#!/bin/bash
# LIGHTWEIGHT wrapper untuk video generation
# TIDAK melalui agent delegation, langsung eksekusi script
# Dipakai untuk hindari context bloat

PROMPT="$1"
CAPTION="${2:-Video dari Veo}"
DURATION="${3:-6}"
MODEL="${4:-veo-3.0-fast-generate-001}"

# Langsung panggil script asli tanpa agent overhead
exec /root/.openclaw/workspace/scripts/generate-video.sh "$PROMPT" "$CAPTION" "$DURATION" "$MODEL"
