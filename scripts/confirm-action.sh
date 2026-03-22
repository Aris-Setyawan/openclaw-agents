#!/bin/bash
# confirm-action.sh - Interactive confirmation for expensive/risky operations
# Usage: confirm-action.sh "<action>" "[cost]" "[details]"
#
# Returns: 0 (approved), 1 (denied)
#
# Example:
#   if confirm-action.sh "Generate video" "~Rp 15K" "Duration: 6s"; then
#     echo "Approved"
#   fi

ACTION="$1"
COST="${2:-Unknown cost}"
DETAILS="$3"

if [ -z "$ACTION" ]; then
  echo "Usage: confirm-action.sh <action> [cost] [details]" >&2
  exit 1
fi

# Check if running in non-interactive mode (piped, automation)
if [ ! -t 0 ]; then
  echo "⚠️  Non-interactive mode detected - skipping confirmation" >&2
  echo "   To require confirmation, run in interactive terminal" >&2
  exit 0  # Allow by default in automation (or change to 1 for strict)
fi

# Display confirmation prompt
echo "" >&2
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
echo "🚨 CONFIRMATION REQUIRED" >&2
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
echo "" >&2
echo "Action: $ACTION" >&2
echo "Cost:   $COST" >&2
if [ -n "$DETAILS" ]; then
  echo "Details: $DETAILS" >&2
fi
echo "" >&2
echo "⚠️  This action may cost money or be irreversible." >&2
echo "" >&2
read -p "Proceed? [y/N]: " -n 1 -r REPLY >&2
echo "" >&2

case "$REPLY" in
  y|Y)
    echo "✅ Confirmed. Proceeding..." >&2
    exit 0
    ;;
  *)
    echo "❌ Cancelled by user" >&2
    exit 1
    ;;
esac
