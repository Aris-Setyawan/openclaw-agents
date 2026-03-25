#!/bin/bash
# gemini-tts.sh — Generate TTS audio using Gemini 2.5 Flash TTS (free, natural voice)
# Usage: gemini-tts.sh "Text to speak" [--send] [--voice NAME] [--output FILE]
#
# Examples:
#   gemini-tts.sh "Halo mas Aris!"                          # → /tmp/gemini-tts-output.mp3
#   gemini-tts.sh "Halo!" --send                            # → generate + send to Telegram
#   gemini-tts.sh "Hello!" --voice Puck --send              # → male voice + send
#   gemini-tts.sh "Hello!" --output /tmp/custom.mp3         # → custom output path
#
# Voices (30 available):
#   Female (recommended): Kore, Aoede, Leda, Zephyr, Despina
#   Male: Puck, Charon, Fenrir, Orus, Enceladus
#   Full list: Achernar, Achird, Algenib, Algieba, Alnilam, Aoede, Autonoe,
#     Callirrhoe, Charon, Despina, Enceladus, Erinome, Fenrir, Gacrux, Iapetus,
#     Kore, Laomedeia, Leda, Orus, Puck, Pulcherrima, Rasalgethi, Sadachbia,
#     Sadaltager, Schedar, Sulafat, Umbriel, Vindemiatrix, Zephyr, Zubenelgenubi
#
# Default voice: Kore (Female) — Santa's voice 🧑‍🎄
# Cost: FREE (Gemini API free tier)
# Quality: ⭐⭐⭐⭐⭐ (very natural, multi-language)

set -euo pipefail

# --- Config ---
GEMINI_KEY="AIzaSyDNovWNTRyvJ8ukr_1bsw8jofoltB7PSJQ"
MODEL="gemini-2.5-flash-preview-tts"
API_URL="https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${GEMINI_KEY}"
DEFAULT_VOICE="Kore"
DEFAULT_OUTPUT="/tmp/gemini-tts-output.mp3"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Parse args ---
TEXT=""
VOICE="$DEFAULT_VOICE"
OUTPUT="$DEFAULT_OUTPUT"
SEND=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --send)
            SEND=true
            shift
            ;;
        --voice)
            VOICE="$2"
            shift 2
            ;;
        --output)
            OUTPUT="$2"
            shift 2
            ;;
        *)
            if [ -z "$TEXT" ]; then
                TEXT="$1"
            fi
            shift
            ;;
    esac
done

if [ -z "$TEXT" ]; then
    echo "Usage: gemini-tts.sh \"text\" [--send] [--voice NAME] [--output FILE]"
    exit 1
fi

echo "🎙️ Generating Gemini TTS..."
echo "   Voice: $VOICE"
echo "   Model: $MODEL"
echo "   Text: ${TEXT:0:80}$([ ${#TEXT} -gt 80 ] && echo '...')"

# --- Generate audio ---
RAW_FILE="/tmp/gemini-tts-raw-$$.json"
PCM_FILE="/tmp/gemini-tts-pcm-$$.wav"

curl -s -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -d "$(python3 -c "
import json
print(json.dumps({
    'contents': [{'parts': [{'text': '''$TEXT'''}]}],
    'generationConfig': {
        'responseModalities': ['AUDIO'],
        'speechConfig': {
            'voiceConfig': {
                'prebuiltVoiceConfig': {
                    'voiceName': '$VOICE'
                }
            }
        }
    }
}))
" 2>/dev/null || echo "{}")" -o "$RAW_FILE" 2>&1

# --- Extract audio ---
python3 -c "
import json, base64, sys
with open('$RAW_FILE') as f:
    data = json.load(f)
if 'error' in data:
    print(f'❌ API Error: {data[\"error\"][\"message\"]}', file=sys.stderr)
    sys.exit(1)
if 'candidates' in data:
    for part in data['candidates'][0]['content']['parts']:
        if 'inlineData' in part:
            audio = base64.b64decode(part['inlineData']['data'])
            with open('$PCM_FILE', 'wb') as out:
                out.write(audio)
            print(f'PCM extracted: {len(audio)} bytes')
            sys.exit(0)
print('❌ No audio in response', file=sys.stderr)
sys.exit(1)
" 2>&1

if [ ! -f "$PCM_FILE" ] || [ ! -s "$PCM_FILE" ]; then
    echo "❌ TTS generation failed!"
    rm -f "$RAW_FILE" "$PCM_FILE"
    exit 1
fi

# --- Convert PCM to MP3 ---
ffmpeg -y -f s16le -ar 24000 -ac 1 -i "$PCM_FILE" -q:a 2 "$OUTPUT" 2>/dev/null

# Cleanup temp files
rm -f "$RAW_FILE" "$PCM_FILE"

if [ ! -f "$OUTPUT" ] || [ ! -s "$OUTPUT" ]; then
    echo "❌ MP3 conversion failed!"
    exit 1
fi

SIZE=$(du -h "$OUTPUT" | cut -f1)
echo "✅ Generated: $OUTPUT ($SIZE)"

# --- Send to Telegram ---
if [ "$SEND" = true ]; then
    if [ -f "$SCRIPT_DIR/telegram-send.sh" ]; then
        echo "📤 Sending to Telegram..."
        "$SCRIPT_DIR/telegram-send.sh" "$OUTPUT" "🎙️ Gemini TTS — Voice: $VOICE"
        echo "✅ Sent!"
    else
        echo "⚠️ telegram-send.sh not found, skipping send"
    fi
fi
