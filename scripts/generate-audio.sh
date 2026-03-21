#!/bin/bash
# Generate audio/suara via TTS + kirim ke Telegram
# Usage: generate-audio.sh "<teks>" "[caption]" "[voice]" "[model]"
#
# Voice Google: Aoede, Charon, Fenrir, Kore, Puck (en) — pilih sesuai karakter
# Voice OpenAI: alloy, echo, fable, nova, onyx, shimmer
#
# Contoh:
#   generate-audio.sh "Halo mas Aris, selamat pagi!"
#   generate-audio.sh "Selamat datang" "caption" "nova" openai

TEXT="$1"
CAPTION="${2:-Pesan suara}"
VOICE="${3:-Aoede}"
PROVIDER="${4:-google}"

if [ -z "$TEXT" ]; then
  echo "Usage: generate-audio.sh <teks> [caption] [voice] [provider: google|openai]" >&2
  exit 1
fi

OUT=/tmp/audio-$(date +%s).mp3

# ── PRIMARY: Google Gemini TTS ─────────────────────────────────────────────
google_tts() {
  GEMINI_KEY=$(python3 -c "import json; d=json.load(open('/root/.openclaw/agents/agent1/agent/auth-profiles.json')); print(d['profiles']['google:default']['key'])" 2>/dev/null)

  echo "[tts] Google Gemini TTS, voice=$VOICE..." >&2

  RESPONSE=$(curl -s -X POST \
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-tts:generateContent?key=${GEMINI_KEY}" \
    -H "Content-Type: application/json" \
    -d "{
      \"contents\": [{\"parts\": [{\"text\": \"$TEXT\"}]}],
      \"generationConfig\": {
        \"responseModalities\": [\"AUDIO\"],
        \"speechConfig\": {\"voiceConfig\": {\"prebuiltVoiceConfig\": {\"voiceName\": \"$VOICE\"}}}
      }
    }")

  ERROR=$(echo "$RESPONSE" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('error',{}).get('message',''))" 2>/dev/null)
  if [ -n "$ERROR" ]; then
    echo "[tts] Google error: $ERROR" >&2
    return 1
  fi

  # Decode base64 PCM → convert ke mp3 via ffmpeg atau simpan langsung
  echo "$RESPONSE" | python3 -c "
import json, sys, base64, struct, wave, io

d = json.load(sys.stdin)
parts = d.get('candidates',[{}])[0].get('content',{}).get('parts',[])
for p in parts:
    if 'inlineData' in p:
        raw = base64.b64decode(p['inlineData']['data'])
        # PCM L16 24kHz mono → WAV
        with wave.open('$OUT'.replace('.mp3','.wav'), 'wb') as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(24000)
            wf.writeframes(raw)
        print('wav_saved')
        break
" 2>/dev/null

  WAV="${OUT%.mp3}.wav"
  if [ -f "$WAV" ]; then
    # Convert WAV ke MP3 jika ffmpeg tersedia
    if command -v ffmpeg &>/dev/null; then
      ffmpeg -y -i "$WAV" -q:a 4 "$OUT" -loglevel quiet
      rm -f "$WAV"
    else
      mv "$WAV" "$OUT"
    fi
    return 0
  fi
  return 1
}

# ── FALLBACK: OpenAI TTS ───────────────────────────────────────────────────
openai_tts() {
  OPENAI_KEY=$(python3 -c "
import json
# Coba auth-profiles dulu
d = json.load(open('/root/.openclaw/agents/agent1/agent/auth-profiles.json'))
k = d.get('profiles',{}).get('openai:default',{}).get('key','')
print(k)
" 2>/dev/null)

  # Fallback ke gateway service env
  if [ -z "$OPENAI_KEY" ]; then
    OPENAI_KEY=$(grep OPENAI_API_KEY /etc/systemd/system/openclaw-gateway.service 2>/dev/null | cut -d= -f2-)
  fi

  OAI_VOICE="${VOICE:-nova}"
  # Map Google voice names ke OpenAI jika perlu
  case "$OAI_VOICE" in
    Aoede|Kore) OAI_VOICE="nova" ;;
    Charon|Fenrir) OAI_VOICE="onyx" ;;
    Puck) OAI_VOICE="fable" ;;
  esac

  echo "[tts] OpenAI TTS fallback, voice=$OAI_VOICE..." >&2

  curl -s -X POST https://api.openai.com/v1/audio/speech \
    -H "Authorization: Bearer $OPENAI_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"tts-1\",\"input\":\"$TEXT\",\"voice\":\"$OAI_VOICE\"}" \
    -o "$OUT"

  [ -f "$OUT" ] && [ -s "$OUT" ] && file "$OUT" | grep -q "MPEG\|audio"
}

# ── Run ────────────────────────────────────────────────────────────────────
if [ "$PROVIDER" = "openai" ]; then
  openai_tts || { echo "ERROR: OpenAI TTS gagal" >&2; exit 1; }
else
  google_tts || openai_tts || { echo "ERROR: Semua TTS gagal" >&2; exit 1; }
fi

if [ -f "$OUT" ] && [ -s "$OUT" ]; then
  SIZE=$(ls -lh "$OUT" | awk '{print $5}')
  echo "[tts] Audio saved: $OUT ($SIZE)" >&2
  /root/.openclaw/workspace/scripts/telegram-send.sh "$OUT" "$CAPTION"
  echo "AUDIO_SENT_OK"
  exit 0
fi

echo "ERROR: File audio tidak terbuat" >&2
exit 1
