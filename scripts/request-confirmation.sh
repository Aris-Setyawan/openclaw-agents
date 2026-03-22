#!/bin/bash
# request-confirmation.sh - Request confirmation via Telegram message
# For Telegram bot usage (non-interactive)
#
# Usage: request-confirmation.sh "<action>" "[cost]" "[details]"
# Returns: Always 1 (deny) and sends confirmation request to user
#
# Workflow:
#   1. Agent sends confirmation message to Telegram
#   2. User replies "yes" or "no" in next message
#   3. Agent checks reply and proceeds or cancels

ACTION="$1"
COST="${2:-Unknown cost}"
DETAILS="$3"

TELEGRAM_SEND="/root/.openclaw/workspace/scripts/telegram-send.sh"

# Build confirmation message
MSG="🚨 **CONFIRMATION REQUIRED**

**Action:** $ACTION
**Cost:** $COST"

if [ -n "$DETAILS" ]; then
  MSG="$MSG
**Details:** $DETAILS"
fi

MSG="$MSG

⚠️ This action may cost money or be irreversible.

**Reply:**
• \`yes\` or \`y\` → Proceed
• \`no\` or \`n\` → Cancel
• \`stop\` → Cancel immediately"

# Send confirmation request to Telegram
"$TELEGRAM_SEND" "" "$MSG"

# Return denial code (agent must wait for user reply)
echo "⏸️  Awaiting user confirmation via Telegram..." >&2
exit 1  # Deny by default, user must explicitly approve in next message
