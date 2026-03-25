#!/bin/bash
# Check GitHub activity for your repos
SCRIPT_DIR="$(dirname "$0")"

echo "🐙 GitHub Activity — $(date '+%Y-%m-%d %H:%M')"

# List recent notifications
echo "📬 Recent notifications:"
gh api notifications --jq '.[0:5] | .[] | "  • [\(.subject.type)] \(.subject.title)"' 2>/dev/null || echo "  No notifications"

# Check repos with recent activity
echo ""
echo "📊 Your repos with recent pushes:"
gh repo list --limit 5 --json name,pushedAt --jq '.[] | "  • \(.name) — last push: \(.pushedAt)"' 2>/dev/null || echo "  No repos found"
