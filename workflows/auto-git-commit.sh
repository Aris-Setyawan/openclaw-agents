#!/bin/bash
# Auto-commit workspace changes to git
# Run every 6 hours or on-demand

cd /root/.openclaw/workspace || exit 1

if [ ! -d .git ]; then
    echo "❌ Not a git repository"
    exit 1
fi

# Check for changes
if git status --porcelain | grep -q .; then
    echo "📦 Changes detected, committing..."
    git add .
    git commit -m "Auto-commit $(date '+%Y-%m-%d %H:%M')"
    
    # Push if remote exists
    if git remote -v | grep -q origin; then
        git push origin main 2>&1 | tail -3
    fi
    echo "✅ Auto-commit complete"
else
    echo "✅ No changes to commit"
fi
