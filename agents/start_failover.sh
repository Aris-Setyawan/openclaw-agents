#!/bin/bash
# Start the OpenClaw Agent Failover Monitor

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="$SCRIPT_DIR/failover.pid"
LOG_FILE="$SCRIPT_DIR/failover.log"

# Load API keys dari environment atau file .env lokal (JANGAN hardcode di sini)
# Setup: copy .env.example ke .env dan isi dengan key asli
ENV_FILE="$SCRIPT_DIR/.env"
if [ -f "$ENV_FILE" ]; then
  set -a && source "$ENV_FILE" && set +a
fi

# Validasi key tersedia
if [ -z "$ANTHROPIC_API_KEY" ] || [ -z "$DEEPSEEK_API_KEY" ]; then
  echo "ERROR: API keys tidak ditemukan. Buat $SCRIPT_DIR/.env dari .env.example"
  exit 1
fi

case "${1:-start}" in
  start)
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
      echo "Failover monitor already running (PID $(cat "$PID_FILE"))"
      exit 0
    fi
    echo "Starting failover monitor..."
    nohup python3 "$SCRIPT_DIR/agent_failover.py" \
      --config "$SCRIPT_DIR/failover_config.json" \
      >> "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"
    echo "Started (PID $!). Log: $LOG_FILE"
    ;;

  stop)
    if [ -f "$PID_FILE" ]; then
      PID=$(cat "$PID_FILE")
      kill "$PID" 2>/dev/null && echo "Stopped (PID $PID)" || echo "Process not found"
      rm -f "$PID_FILE"
    else
      echo "Not running"
    fi
    ;;

  restart)
    "$0" stop
    sleep 2
    "$0" start
    ;;

  status)
    python3 "$SCRIPT_DIR/agent_failover.py" \
      --config "$SCRIPT_DIR/failover_config.json" \
      --status
    ;;

  once)
    python3 "$SCRIPT_DIR/agent_failover.py" \
      --config "$SCRIPT_DIR/failover_config.json" \
      --once
    ;;

  failover)
    # Usage: ./start_failover.sh failover agent5
    AGENT="${2:-agent5}"
    python3 "$SCRIPT_DIR/agent_failover.py" \
      --config "$SCRIPT_DIR/failover_config.json" \
      --failover "$AGENT"
    ;;

  restore)
    python3 "$SCRIPT_DIR/agent_failover.py" \
      --config "$SCRIPT_DIR/failover_config.json" \
      --restore
    ;;

  log)
    tail -f "$LOG_FILE"
    ;;

  *)
    echo "Usage: $0 {start|stop|restart|status|once|failover <agent>|restore|log}"
    exit 1
    ;;
esac
