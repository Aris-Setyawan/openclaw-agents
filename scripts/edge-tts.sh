#!/bin/bash
# edge-tts.sh — Generate TTS audio using Microsoft Edge TTS (free, no API key)
# Usage: edge-tts.sh "Text to speak" [output_file] [voice] [--send]
#
# Examples:
#   edge-tts.sh "Halo mas Aris!"                          # → /tmp/edge-tts-output.mp3
#   edge-tts.sh "Hello world" /tmp/hello.mp3               # → custom output
#   edge-tts.sh "Hello" /tmp/hello.mp3 en-US-JennyNeural   # → custom voice
#   edge-tts.sh "Halo!" --send                             # → generate + send to Telegram
#
# Default voice: id-ID-GadisNeural (Female Indonesian)
# List all voices: edge-tts --list-voices

set -euo pipefail

TEXT="${1:?Usage: edge-tts.sh \"text\" [output_file] [voice] [--send]}"
SEND=false

# Parse args
OUTPUT="/tmp/edge-tts-output.mp3"
VOICE="id-ID-GadisNeural"

shift
for arg in "$@"; do
    case "$arg" in
        --send)
            SEND=true
            ;;
        *.mp3|*.wav|*.ogg|/tmp/*|/root/*)
            OUTPUT="$arg"
            ;;
        *-*Neural|*-*Online)
            VOICE="$arg"
            ;;
    esac
done

# Detect language and auto-select voice if text looks English
if echo "$TEXT" | grep -qiP '^[a-z0-9\s\.,!?\-\:;\"\x27]+$' && [ "$VOICE" = "id-ID-GadisNeural" ]; then
    # Check if text is mostly ASCII/English
    ascii_ratio=$(echo "$TEXT" | grep -oP '[a-zA-Z]' | wc -l)
    total_chars=$(echo "$TEXT" | wc -c)
    if [ "$ascii_ratio" -gt "$((total_chars * 80 / 100))" ] 2>/dev/null; then
        VOICE="en-US-JennyNeural"
    fi
fi

echo "🎙️ Generating TTS..."
echo "   Voice: $VOICE"
echo "   Output: $OUTPUT"
echo "   Text: ${TEXT:0:80}$([ ${#TEXT} -gt 80 ] && echo '...')"

edge-tts --voice "$VOICE" --text "$TEXT" --write-media "$OUTPUT" 2>&1

if [ ! -f "$OUTPUT" ] || [ ! -s "$OUTPUT" ]; then
    echo "❌ TTS generation failed!"
    exit 1
fi

SIZE=$(du -h "$OUTPUT" | cut -f1)
echo "✅ Generated: $OUTPUT ($SIZE)"

# Send to Telegram if --send flag
if [ "$SEND" = true ]; then
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    if [ -f "$SCRIPT_DIR/telegram-send.sh" ]; then
        echo "📤 Sending to Telegram..."
        "$SCRIPT_DIR/telegram-send.sh" "$OUTPUT" "🎙️ Voice: $VOICE"
        echo "✅ Sent!"
    else
        echo "⚠️ telegram-send.sh not found, skipping send"
    fi
fi
