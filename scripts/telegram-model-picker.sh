#!/bin/bash
# Telegram inline keyboard model picker
# Usage:
#   telegram-model-picker.sh image "<prompt>"   → prints chosen model code
#   telegram-model-picker.sh video "<prompt>"   → prints chosen model code
#   telegram-model-picker.sh confirm "<pesan>"  → prints "yes" atau "no"
#
# Timeout 60 detik → fallback ke default (pilihan pertama)

TYPE="$1"
PROMPT="$2"
CHAT_ID="${3:-613802669}"
TIMEOUT_SECS=60

BOT_TOKEN=$(python3 -c "import json; d=json.load(open('/root/.openclaw/openclaw.json')); print(d['channels']['telegram']['botToken'])" 2>/dev/null)

if [ -z "$BOT_TOKEN" ]; then
  echo "default"
  exit 0
fi

# ── Helper: send message with inline keyboard ──────────────────────────────
send_keyboard() {
  local TEXT="$1"
  local KEYBOARD_JSON="$2"

  python3 - <<PYEOF
import json, subprocess, sys

text = """$TEXT"""
keyboard = $KEYBOARD_JSON
chat_id = "$CHAT_ID"
bot_token = "$BOT_TOKEN"

payload = {
    "chat_id": chat_id,
    "text": text,
    "parse_mode": "Markdown",
    "reply_markup": {"inline_keyboard": keyboard}
}

result = subprocess.run([
    "curl", "-s", "-X", "POST",
    f"https://api.telegram.org/bot{bot_token}/sendMessage",
    "-H", "Content-Type: application/json",
    "-d", json.dumps(payload)
], capture_output=True, text=True)

d = json.loads(result.stdout)
print(d.get("result", {}).get("message_id", ""))
PYEOF
}

# ── Helper: edit message ───────────────────────────────────────────────────
edit_message() {
  local MSG_ID="$1"
  local TEXT="$2"
  python3 -c "
import json, subprocess
payload = {'chat_id': '$CHAT_ID', 'message_id': $MSG_ID, 'text': '''$TEXT''', 'parse_mode': 'Markdown'}
subprocess.run(['curl','-s','-X','POST',
  'https://api.telegram.org/bot$BOT_TOKEN/editMessageText',
  '-H','Content-Type: application/json',
  '-d', json.dumps(payload)], capture_output=True)
" 2>/dev/null
}

# ── Helper: answer callback query ─────────────────────────────────────────
answer_callback() {
  local CQ_ID="$1"
  local TEXT="$2"
  curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/answerCallbackQuery" \
    -H "Content-Type: application/json" \
    -d "{\"callback_query_id\":\"$CQ_ID\",\"text\":\"$TEXT\"}" > /dev/null
}

# ── Get offset sebelum send ────────────────────────────────────────────────
START_OFFSET=$(curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates?limit=1" | python3 -c "
import json,sys
d=json.load(sys.stdin)
updates = d.get('result',[])
print(updates[-1]['update_id'] + 1 if updates else 0)
" 2>/dev/null)
START_OFFSET="${START_OFFSET:-0}"

# ── Build keyboard & text berdasarkan type ─────────────────────────────────
if [ "$TYPE" = "image" ]; then
  MSG_TEXT="🖼 *Generate Foto*

📝 Prompt: \`$(echo "$PROMPT" | head -c 100)\`

Pilih model yang mau dipakai:"

  KEYBOARD='[
    [{"text":"🔵 Gemini Imagen (Google)","callback_data":"gemini"},{"text":"⚡ Flux Pro (kie.ai)","callback_data":"flux_pro"}],
    [{"text":"💎 Flux Max (kie.ai)","callback_data":"flux_max"},{"text":"🤖 GPT-4o Image (kie.ai)","callback_data":"gpt4o"}],
    [{"text":"🌟 Imagen 4 (kie.ai)","callback_data":"imagen4"},{"text":"🌟 Imagen 4 Ultra","callback_data":"imagen4u"}],
    [{"text":"🎨 Seedream 4.0 (kie.ai)","callback_data":"seedream4"},{"text":"✨ GPT-Image-1.5","callback_data":"gpt15"}]
  ]'
  DEFAULT_MODEL="gemini"

elif [ "$TYPE" = "video" ]; then
  MSG_TEXT="🎬 *Generate Video*

📝 Prompt: \`$(echo "$PROMPT" | head -c 100)\`

Pilih model yang mau dipakai:"

  KEYBOARD='[
    [{"text":"🚀 Veo3 Fast (kie.ai)","callback_data":"veo3f"},{"text":"🎥 Veo3 Quality (kie.ai)","callback_data":"veo3q"}],
    [{"text":"🎬 Runway Gen4 (kie.ai)","callback_data":"runway"},{"text":"🌟 Kling 3.0 (kie.ai)","callback_data":"kling3"}],
    [{"text":"🤖 Sora 2 (kie.ai)","callback_data":"sora2"},{"text":"📹 Hailuo Standard","callback_data":"hailuo"}],
    [{"text":"🔵 Google Veo (direct)","callback_data":"gveo"},{"text":"🌀 Wan (Alibaba)","callback_data":"wan"}]
  ]'
  DEFAULT_MODEL="veo3f"

elif [ "$TYPE" = "confirm" ]; then
  MSG_TEXT="⚠️ *Konfirmasi*

$PROMPT"

  KEYBOARD='[
    [{"text":"✅ Ya, lanjut","callback_data":"yes"},{"text":"❌ Tidak","callback_data":"no"}]
  ]'
  DEFAULT_MODEL="no"

else
  echo "default"
  exit 0
fi

# ── Kirim keyboard ─────────────────────────────────────────────────────────
MSG_ID=$(send_keyboard "$MSG_TEXT" "$KEYBOARD")

if [ -z "$MSG_ID" ]; then
  echo "$DEFAULT_MODEL"
  exit 0
fi

# ── Poll untuk callback query ──────────────────────────────────────────────
CHOSEN=""
OFFSET="$START_OFFSET"
ELAPSED=0

while [ $ELAPSED -lt $TIMEOUT_SECS ]; do
  sleep 3
  ELAPSED=$((ELAPSED + 3))

  UPDATES=$(curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates?offset=${OFFSET}&timeout=2" 2>/dev/null)

  RESULT=$(echo "$UPDATES" | python3 -c "
import json,sys
d=json.load(sys.stdin)
updates = d.get('result',[])
for u in updates:
    cq = u.get('callback_query')
    if cq and str(cq.get('message',{}).get('chat',{}).get('id','')) == '$CHAT_ID':
        uid = u.get('update_id')
        data = cq.get('data','')
        cqid = cq.get('id','')
        print(f'{uid}|{data}|{cqid}')
        break
" 2>/dev/null)

  if [ -n "$RESULT" ]; then
    NEW_OFFSET=$(echo "$RESULT" | cut -d'|' -f1)
    CHOSEN=$(echo "$RESULT" | cut -d'|' -f2)
    CQ_ID=$(echo "$RESULT" | cut -d'|' -f3)

    # Answer callback
    answer_callback "$CQ_ID" "✅ Dipilih!"

    # Update offset
    OFFSET=$((NEW_OFFSET + 1))

    # Edit message — hapus keyboard, tampilkan pilihan
    if [ "$TYPE" = "confirm" ]; then
      LABEL=$([ "$CHOSEN" = "yes" ] && echo "✅ Ya, lanjut" || echo "❌ Tidak")
      edit_message "$MSG_ID" "${MSG_TEXT}

*Pilihan: ${LABEL}*"
    else
      edit_message "$MSG_ID" "${MSG_TEXT}

*✅ Model dipilih: ${CHOSEN}*"
    fi

    break
  fi
done

# ── Output ─────────────────────────────────────────────────────────────────
if [ -z "$CHOSEN" ]; then
  # Timeout — edit message dan pakai default
  if [ -n "$MSG_ID" ]; then
    edit_message "$MSG_ID" "${MSG_TEXT}

*⏱ Timeout — pakai default: ${DEFAULT_MODEL}*"
  fi
  echo "$DEFAULT_MODEL"
else
  echo "$CHOSEN"
fi
