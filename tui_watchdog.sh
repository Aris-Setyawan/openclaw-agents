#!/bin/bash
# OpenClaw TUI Watchdog
# Detects and recovers from hung TUI sessions / stale locks
# Usage:
#   ./tui_watchdog.sh             — check + clean stale locks
#   ./tui_watchdog.sh clean       — clean stale locks only
#   ./tui_watchdog.sh watch [N]   — background monitor (check every N seconds, default 30)
#   ./tui_watchdog.sh stop        — stop background monitor
#   ./tui_watchdog.sh status      — show running TUI processes & lock files

OPENCLAW_DIR="/root/.openclaw"
SESSIONS_DIR="$OPENCLAW_DIR/agents"
PID_FILE="/root/openclaw/watchdog.pid"
LOG_FILE="/root/openclaw/watchdog.log"
HANG_TIMEOUT="${HANG_TIMEOUT:-120}"   # seconds of no output before TUI is considered hung

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }

# ── stale lock cleanup ────────────────────────────────────────────────────────

clean_stale_locks() {
  local cleaned=0
  local locks
  locks=$(find "$SESSIONS_DIR" -name "*.jsonl.lock" 2>/dev/null)
  if [ -z "$locks" ]; then
    echo "No lock files found."
    return 0
  fi

  while IFS= read -r lock; do
    if [ ! -f "$lock" ]; then continue; fi
    local pid
    pid=$(cat "$lock" 2>/dev/null | tr -d '[:space:]')
    if [ -z "$pid" ]; then
      echo "Removing empty lock: $lock"
      rm -f "$lock"
      ((cleaned++))
    elif ! kill -0 "$pid" 2>/dev/null; then
      echo "Removing stale lock (dead PID $pid): $lock"
      rm -f "$lock"
      ((cleaned++))
    else
      echo "Lock held by live PID $pid: $lock"
    fi
  done <<< "$locks"

  echo "Cleaned $cleaned stale lock(s)."
}

# ── detect hung TUI ───────────────────────────────────────────────────────────

find_tui_pids() {
  pgrep -f "openclaw tui\|openclaw.*--tui\|node.*openclaw" 2>/dev/null
}

check_hung_tui() {
  local pids
  pids=$(find_tui_pids)
  if [ -z "$pids" ]; then
    echo "No OpenClaw TUI processes found."
    return
  fi

  echo "OpenClaw TUI PIDs: $pids"
  while IFS= read -r pid; do
    [ -z "$pid" ] && continue
    local cmd
    cmd=$(ps -p "$pid" -o comm= 2>/dev/null)
    local elapsed
    elapsed=$(ps -p "$pid" -o etimes= 2>/dev/null | tr -d ' ')
    local stat
    stat=$(cat /proc/"$pid"/status 2>/dev/null | grep "^State:" | awk '{print $2}')
    echo "  PID $pid ($cmd): state=$stat, running ${elapsed}s"

    # Check if process is stuck in D (uninterruptible sleep) or Z (zombie)
    if [ "$stat" = "D" ] || [ "$stat" = "Z" ]; then
      log "WARNING: PID $pid is in state $stat (hung/zombie)"
    fi
  done <<< "$pids"
}

kill_hung_tui() {
  local pids
  pids=$(find_tui_pids)
  if [ -z "$pids" ]; then
    echo "No OpenClaw TUI processes to kill."
    return
  fi
  echo "Killing TUI processes: $pids"
  echo "$pids" | xargs kill -TERM 2>/dev/null
  sleep 3
  # Force kill any survivors
  local survivors
  survivors=$(find_tui_pids)
  if [ -n "$survivors" ]; then
    echo "Force-killing survivors: $survivors"
    echo "$survivors" | xargs kill -KILL 2>/dev/null
  fi
  log "Killed TUI processes: $pids"
}

# ── status ────────────────────────────────────────────────────────────────────

show_status() {
  echo "=== OpenClaw TUI Status ==="
  check_hung_tui

  echo ""
  echo "=== Lock Files ==="
  local locks
  locks=$(find "$SESSIONS_DIR" -name "*.jsonl.lock" 2>/dev/null)
  if [ -z "$locks" ]; then
    echo "No lock files."
  else
    while IFS= read -r lock; do
      local pid
      pid=$(cat "$lock" 2>/dev/null | tr -d '[:space:]')
      if [ -z "$pid" ]; then
        echo "  [EMPTY]   $lock"
      elif kill -0 "$pid" 2>/dev/null; then
        echo "  [LIVE:$pid] $lock"
      else
        echo "  [STALE:$pid] $lock  ← can be cleaned"
      fi
    done <<< "$locks"
  fi

  echo ""
  echo "=== Session Dirs ==="
  find "$SESSIONS_DIR" -maxdepth 3 -name "sessions" -type d 2>/dev/null | while read -r d; do
    local count
    count=$(ls "$d"/*.jsonl 2>/dev/null | wc -l)
    echo "  $d: $count session file(s)"
  done
}

# ── background watch loop ─────────────────────────────────────────────────────

watch_loop() {
  local interval="${1:-30}"
  log "Watchdog started (interval=${interval}s, hang_timeout=${HANG_TIMEOUT}s)"

  while true; do
    # Clean stale locks silently
    local locks
    locks=$(find "$SESSIONS_DIR" -name "*.jsonl.lock" 2>/dev/null)
    while IFS= read -r lock; do
      [ -z "$lock" ] && continue
      local pid
      pid=$(cat "$lock" 2>/dev/null | tr -d '[:space:]')
      if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then
        log "Auto-removed stale lock (PID=$pid): $lock"
        rm -f "$lock"
      fi
    done <<< "$locks"

    # Check for zombie TUI
    local pids
    pids=$(find_tui_pids)
    while IFS= read -r pid; do
      [ -z "$pid" ] && continue
      local stat
      stat=$(cat /proc/"$pid"/status 2>/dev/null | grep "^State:" | awk '{print $2}')
      if [ "$stat" = "Z" ]; then
        log "WARNING: TUI PID $pid is a zombie. Manual cleanup may be needed."
      fi
    done <<< "$pids"

    sleep "$interval"
  done
}

start_watch() {
  local interval="${1:-30}"
  if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "Watchdog already running (PID $(cat "$PID_FILE"))"
    return
  fi
  watch_loop "$interval" &
  echo $! > "$PID_FILE"
  echo "Watchdog started (PID $!, interval=${interval}s). Log: $LOG_FILE"
}

stop_watch() {
  if [ -f "$PID_FILE" ]; then
    local pid
    pid=$(cat "$PID_FILE")
    kill "$pid" 2>/dev/null && echo "Watchdog stopped (PID $pid)" || echo "Process not found"
    rm -f "$PID_FILE"
  else
    echo "Watchdog not running"
  fi
}

# ── main ──────────────────────────────────────────────────────────────────────

CMD="${1:-check}"
case "$CMD" in
  check)
    echo "=== Cleaning stale locks ==="
    clean_stale_locks
    echo ""
    show_status
    ;;
  clean)
    clean_stale_locks
    ;;
  status)
    show_status
    ;;
  kill)
    clean_stale_locks
    kill_hung_tui
    ;;
  watch)
    start_watch "${2:-30}"
    ;;
  stop)
    stop_watch
    ;;
  log)
    tail -f "$LOG_FILE"
    ;;
  *)
    echo "Usage: $0 {check|clean|status|kill|watch [interval_seconds]|stop|log}"
    echo ""
    echo "  check   — clean stale locks + show status (default)"
    echo "  clean   — remove stale lock files only"
    echo "  status  — show TUI processes and lock files"
    echo "  kill    — clean locks + kill hung TUI processes"
    echo "  watch N — run background monitor every N seconds (default 30)"
    echo "  stop    — stop background monitor"
    echo "  log     — tail watchdog log"
    exit 1
    ;;
esac
