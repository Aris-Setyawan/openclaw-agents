#!/bin/bash
# Start the OpenClaw Agent Failover Monitor

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="$SCRIPT_DIR/failover.pid"
LOG_FILE="$SCRIPT_DIR/failover.log"

# Load env vars (API keys)
export ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-sk-ant-api03-dbd2a9dd51644a0995afcb9ae9d0b42d-kzPIe4VzLOAP4CmO}"
export DEEPSEEK_API_KEY="${DEEPSEEK_API_KEY:-sk-7f9a50b9c1da48d7b50293d4d75d345e}"
export OPENROUTER_API_KEY="${OPENROUTER_API_KEY:-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}"
export DASHSCOPE_API_KEY="${DASHSCOPE_API_KEY:-sk-10c7a430bc39457ebc312279fcfd66fc}"

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
