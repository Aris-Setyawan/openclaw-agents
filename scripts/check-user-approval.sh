#!/bin/bash
# check-user-approval.sh - Check if user message contains approval
# Usage: echo "$USER_MESSAGE" | check-user-approval.sh
# Returns: 0 (approved), 1 (denied), 2 (unclear)

# Read user message from stdin or first argument
if [ -t 0 ]; then
  MESSAGE="$1"
else
  MESSAGE=$(cat)
fi

MESSAGE_LOWER=$(echo "$MESSAGE" | tr '[:upper:]' '[:lower:]')

# Check for explicit approval
if echo "$MESSAGE_LOWER" | grep -Eq '\b(yes|y|ya|ok|oke|proceed|lanjut|lanjutkan|setuju|go)\b'; then
  echo "✅ Approval detected" >&2
  exit 0
fi

# Check for explicit denial
if echo "$MESSAGE_LOWER" | grep -Eq '\b(no|n|tidak|gak|cancel|stop|batal|jangan|wait|tunggu)\b'; then
  echo "❌ Denial detected" >&2
  exit 1
fi

# Unclear/ambiguous
echo "❓ Unclear response - need explicit yes/no" >&2
exit 2
