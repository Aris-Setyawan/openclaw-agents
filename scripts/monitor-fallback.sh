#!/bin/bash
# Monitor model fallback antar agent - kirim notif Telegram saat model berganti
# Auto-revert ke primary model jika sudah sehat kembali
# Jalankan via cron setiap 1 menit

OPENCLAW_DIR="${OPENCLAW_DIR:-/root/.openclaw}"
OPENCLAW_JSON="${OPENCLAW_JSON:-$OPENCLAW_DIR/openclaw.json}"
STATE_FILE="$OPENCLAW_DIR/logs/fallback-state.json"

BOT_TOKEN=$(python3 -c "import json; d=json.load(open('$OPENCLAW_JSON')); print(d['channels']['telegram']['botToken'])" 2>/dev/null)
CHAT_ID=$(python3 -c "import json; d=json.load(open('$OPENCLAW_JSON')); print(d['channels']['telegram']['allowFrom'][0])" 2>/dev/null)

if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
  echo "ERROR: Telegram credentials tidak ditemukan"
  exit 1
fi

send_telegram() {
  local msg="$1"
  curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d "chat_id=${CHAT_ID}&text=${msg}&parse_mode=HTML" > /dev/null
}

# Test apakah primary model sehat (ping singkat)
test_primary_healthy() {
  local provider="$1"  # misal: gemini, deepseek, anthropic
  local proxy_url=""
  local api_key=""
  local model=""

  case "$provider" in
    gemini)
      proxy_url="http://127.0.0.1:9998/v1/chat/completions"
      api_key=$(python3 -c "import json; d=json.load(open('$OPENCLAW_DIR/agents/agent1/agent/auth-profiles.json')); print(d['profiles'].get('google:default',{}).get('key',''))" 2>/dev/null)
      model="gemini-2.5-flash"
      ;;
    deepseek)
      proxy_url="https://api.deepseek.com/v1/chat/completions"
      api_key=$(python3 -c "import json; d=json.load(open('$OPENCLAW_DIR/agents/agent1/agent/auth-profiles.json')); print(d['profiles'].get('deepseek:default',{}).get('key',''))" 2>/dev/null)
      model="deepseek-chat"
      ;;
    anthropic)
      return 0  # Anthropic jarang error, skip test
      ;;
    *)
      return 1
      ;;
  esac

  [ -z "$api_key" ] && return 1

  result=$(curl -s -m 15 -X POST "$proxy_url" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $api_key" \
    -d "{\"model\":\"$model\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":5}" 2>/dev/null)

  echo "$result" | python3 -c "
import json,sys
try:
    d=json.loads(sys.stdin.read())
    if d.get('choices'): exit(0)
    exit(1)
except: exit(1)
" 2>/dev/null
  return $?
}

# Kirim /new command ke agent via Telegram untuk reset session
trigger_session_reset() {
  local agent="$1"
  # Kirim pesan khusus agar agent reset ke primary model
  local msg="/new"
  curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d "chat_id=${CHAT_ID}&text=${msg}" > /dev/null
  sleep 2
}

# Ambil primary model per agent dari openclaw.json
get_primary_provider() {
  local agent="$1"
  python3 -c "
import json
d = json.load(open('$OPENCLAW_JSON'))
agents = d.get('agents', {})
lst = agents.get('list', [])
for a in lst:
    if a.get('id') == '$agent':
        primary = a.get('model', {}).get('primary', '')
        print(primary.split('/')[0] if primary else '')
        exit()
print('')
" 2>/dev/null
}

# Load state sebelumnya
declare -A PREV_MODEL
if [ -f "$STATE_FILE" ]; then
  while IFS='=' read -r key val; do
    PREV_MODEL["$key"]="$val"
  done < <(python3 -c "
import json
d = json.load(open('$STATE_FILE'))
for k, v in d.items():
    print(f'{k}={v}')
" 2>/dev/null)
fi

declare -A CURR_MODEL
FALLBACK_MSGS=()
REVERT_MSGS=()

# Cek session terbaru tiap agent
for AGENT_DIR in "$OPENCLAW_DIR/agents"/*/; do
  AGENT=$(basename "$AGENT_DIR")
  SESSION_DIR="$AGENT_DIR/sessions"

  [ ! -d "$SESSION_DIR" ] && continue

  # Ambil session log terbaru
  LATEST_LOG=$(ls -t "$SESSION_DIR"/*.jsonl 2>/dev/null | head -1)
  [ -z "$LATEST_LOG" ] && continue

  # Ambil 2 message assistant terakhir
  LAST_MODELS=$(python3 -c "
import json, sys

msgs = []
with open('$LATEST_LOG') as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            d = json.loads(line)
            if d.get('type') == 'message' and d.get('message', {}).get('role') == 'assistant':
                m = d['message']
                provider = m.get('provider', '')
                model = m.get('model', '')
                if provider and model:
                    msgs.append(f'{provider}/{model}')
        except:
            pass

if len(msgs) >= 2:
    print(msgs[-2])
    print(msgs[-1])
elif len(msgs) == 1:
    print(msgs[-1])
    print(msgs[-1])
" 2>/dev/null)

  PREV=$(echo "$LAST_MODELS" | head -1)
  CURR=$(echo "$LAST_MODELS" | tail -1)

  [ -z "$CURR" ] && continue

  CURR_MODEL["$AGENT"]="$CURR"
  CURR_PROVIDER=$(echo "$CURR" | cut -d'/' -f1)
  SAVED="${PREV_MODEL[$AGENT]}"
  SAVED_PROVIDER=$(echo "$SAVED" | cut -d'/' -f1)

  # Cek fallback baru
  if [ -n "$SAVED" ] && [ "$SAVED" != "$CURR" ]; then
    FALLBACK_MSGS+=("$AGENT: <b>$SAVED</b> → <b>$CURR</b>")
  elif [ -n "$PREV" ] && [ "$PREV" != "$CURR" ] && [ -z "$SAVED" ]; then
    FALLBACK_MSGS+=("$AGENT: <b>$PREV</b> → <b>$CURR</b>")
  fi

  # Cek apakah sedang di fallback dan primary sudah sehat → auto-revert
  if [ -n "$SAVED" ] && [ "$SAVED" == "$CURR" ]; then
    PRIMARY_PROVIDER=$(get_primary_provider "$AGENT")
    if [ -n "$PRIMARY_PROVIDER" ] && [ "$PRIMARY_PROVIDER" != "$CURR_PROVIDER" ]; then
      # Agent masih di fallback, cek apakah primary sudah sehat
      if test_primary_healthy "$PRIMARY_PROVIDER"; then
        # Primary sehat → trigger reset session
        if [ "$AGENT" == "agent1" ] || [ "$AGENT" == "main" ]; then
          trigger_session_reset "$AGENT"
          REVERT_MSGS+=("$AGENT: primary <b>$PRIMARY_PROVIDER</b> sehat → reset session")
        fi
      fi
    fi
  fi
done

# Kirim notif fallback
if [ ${#FALLBACK_MSGS[@]} -gt 0 ]; then
  HOSTNAME=$(hostname)
  MSG="⚠️ <b>Model Fallback Terdeteksi</b> [$HOSTNAME]"$'\n'
  for m in "${FALLBACK_MSGS[@]}"; do
    MSG+=$'\n'"• $m"
  done
  MSG+=$'\n\n'"<i>$(TZ=Asia/Jakarta date '+%H:%M WIB')</i>"
  send_telegram "$MSG"
fi

# Kirim notif auto-revert
if [ ${#REVERT_MSGS[@]} -gt 0 ]; then
  HOSTNAME=$(hostname)
  MSG="✅ <b>Auto-Revert ke Primary</b> [$HOSTNAME]"$'\n'
  for m in "${REVERT_MSGS[@]}"; do
    MSG+=$'\n'"• $m"
  done
  MSG+=$'\n\n'"<i>$(TZ=Asia/Jakarta date '+%H:%M WIB')</i>"
  send_telegram "$MSG"
fi

# Simpan state terbaru ke fallback-state.json
python3 -c "
import json
data = {}
$(for key in "${!CURR_MODEL[@]}"; do echo "data['${key}'] = '${CURR_MODEL[$key]}'"; done)
json.dump(data, open('$STATE_FILE', 'w'), indent=2)
" 2>/dev/null

# Sync provider ke health-state.json agar dashboard akurat
HEALTH_FILE="$OPENCLAW_DIR/workspace/health-state.json"
if [ -f "$HEALTH_FILE" ]; then
  python3 - << PYEOF 2>/dev/null
import json
from datetime import datetime, timezone

h = json.load(open('$HEALTH_FILE'))
now = datetime.now(timezone.utc).isoformat()

$(for key in "${!CURR_MODEL[@]}"; do
  provider=$(echo "${CURR_MODEL[$key]}" | cut -d'/' -f1)
  echo "if '${key}' in h.get('agents',{}): h['agents']['${key}']['provider'] = '${provider}'; h['agents']['${key}']['last_check'] = now"
done)

h['updated_at'] = now
json.dump(h, open('$HEALTH_FILE', 'w'), indent=2)
PYEOF
fi

exit 0
