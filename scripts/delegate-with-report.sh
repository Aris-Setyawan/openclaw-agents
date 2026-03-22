#!/bin/bash
# delegate-with-report.sh - Auto-reporting task delegation
# Usage: delegate-with-report.sh <target_agent> <task> [completion_msg]
#
# Example:
#   delegate-with-report.sh agent2 "Generate image: ..." "✅ Gambar selesai!"

TARGET_AGENT="$1"
TASK="$2"
COMPLETION_MSG="${3:-✅ Task selesai}"

if [ -z "$TARGET_AGENT" ] || [ -z "$TASK" ]; then
  echo "Usage: delegate-with-report.sh <target_agent> <task> [completion_msg]" >&2
  exit 1
fi

OPENCLAW=/www/server/nvm/versions/node/v22.20.0/bin/openclaw

echo "🔄 Delegating to $TARGET_AGENT..." >&2

# Execute task (synchronous, capture both stdout and stderr)
RESULT=$($OPENCLAW agent --agent "$TARGET_AGENT" --message "$TASK" 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
  # Success - announce completion
  echo "" >&2
  echo "$COMPLETION_MSG" >&2
  
  # Return result to caller
  echo "$RESULT"
  exit 0
else
  # Failure - report error
  echo "❌ Task gagal di $TARGET_AGENT" >&2
  echo "Error: $RESULT" >&2
  exit 1
fi
