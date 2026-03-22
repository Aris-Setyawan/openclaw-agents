#!/bin/bash
# Kirim perkiraan cuaca hari ini ke Telegram
# Usage: send-weather.sh [city]

CITY="${1:-Jakarta}"
OPENCLAW_JSON="${OPENCLAW_JSON:-/root/.openclaw/openclaw.json}"
BOT_TOKEN=$(python3 -c "import json; d=json.load(open('$OPENCLAW_JSON')); print(d['channels']['telegram']['botToken'])")
CHAT_ID=$(python3 -c "import json; d=json.load(open('$OPENCLAW_JSON')); print(d['channels']['telegram']['allowFrom'][0])")
TZ="Asia/Jakarta"

# Ambil cuaca dari wttr.in (JSON format)
WEATHER=$(curl -s "https://wttr.in/${CITY}?format=j1" 2>/dev/null)

if [ -z "$WEATHER" ] || echo "$WEATHER" | grep -q "Unknown location"; then
  MSG="❌ Gagal mengambil data cuaca untuk ${CITY}"
  curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d "chat_id=${CHAT_ID}&text=${MSG}&parse_mode=HTML" > /dev/null
  exit 1
fi

# Parse data cuaca
TEMP_C=$(echo "$WEATHER" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['current_condition'][0]['temp_C'])" 2>/dev/null)
FEELS=$(echo "$WEATHER" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['current_condition'][0]['FeelsLikeC'])" 2>/dev/null)
HUMIDITY=$(echo "$WEATHER" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['current_condition'][0]['humidity'])" 2>/dev/null)
DESC=$(echo "$WEATHER" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['current_condition'][0]['weatherDesc'][0]['value'])" 2>/dev/null)
WIND=$(echo "$WEATHER" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['current_condition'][0]['windspeedKmph'])" 2>/dev/null)
WIND_DIR=$(echo "$WEATHER" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['current_condition'][0]['winddir16Point'])" 2>/dev/null)
UV=$(echo "$WEATHER" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['current_condition'][0]['uvIndex'])" 2>/dev/null)
VISIBILITY=$(echo "$WEATHER" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['current_condition'][0]['visibility'])" 2>/dev/null)

# Forecast hari ini (max/min)
MAX_C=$(echo "$WEATHER" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['weather'][0]['maxtempC'])" 2>/dev/null)
MIN_C=$(echo "$WEATHER" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['weather'][0]['mintempC'])" 2>/dev/null)
RAIN=$(echo "$WEATHER" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['weather'][0]['hourly'][4].get('chanceofrain','0'))" 2>/dev/null)
SUNRISE=$(echo "$WEATHER" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['weather'][0]['astronomy'][0]['sunrise'])" 2>/dev/null)
SUNSET=$(echo "$WEATHER" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['weather'][0]['astronomy'][0]['sunset'])" 2>/dev/null)

# Pilih emoji cuaca
case "$DESC" in
  *"Sunny"*|*"Clear"*)      EMOJI="☀️" ;;
  *"Partly"*|*"Cloudy"*)   EMOJI="⛅" ;;
  *"Overcast"*)             EMOJI="☁️" ;;
  *"Rain"*|*"Drizzle"*)    EMOJI="🌧️" ;;
  *"Thunder"*)              EMOJI="⛈️" ;;
  *"Fog"*|*"Mist"*)        EMOJI="🌫️" ;;
  *)                        EMOJI="🌤️" ;;
esac

# Emoji hujan
if [ "$RAIN" -ge 70 ] 2>/dev/null; then
  RAIN_EMOJI="🌧️ Kemungkinan hujan tinggi"
elif [ "$RAIN" -ge 40 ] 2>/dev/null; then
  RAIN_EMOJI="☂️ Kemungkinan hujan sedang"
else
  RAIN_EMOJI="✅ Cuaca cukup cerah"
fi

NOW=$(TZ=Asia/Jakarta date "+%A, %d %B %Y • %H:%M WIB")

MSG="${EMOJI} <b>Perkiraan Cuaca ${CITY}</b>
📅 ${NOW}

🌡️ <b>Suhu:</b> ${TEMP_C}°C (terasa ${FEELS}°C)
📊 <b>Min/Max:</b> ${MIN_C}°C / ${MAX_C}°C
💧 <b>Kelembaban:</b> ${HUMIDITY}%
💨 <b>Angin:</b> ${WIND} km/h arah ${WIND_DIR}
👁️ <b>Visibilitas:</b> ${VISIBILITY} km
🔆 <b>UV Index:</b> ${UV}
🌅 <b>Matahari:</b> Terbit ${SUNRISE} · Terbenam ${SUNSET}

📋 <b>Kondisi:</b> ${DESC}
🌂 <b>Hujan:</b> ${RAIN}% · ${RAIN_EMOJI}

<i>Data: wttr.in · OpenClaw Weather Bot</i>"

curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -d "chat_id=${CHAT_ID}" \
  --data-urlencode "text=${MSG}" \
  -d "parse_mode=HTML" > /dev/null

echo "✅ Cuaca ${CITY} terkirim ke Telegram"
