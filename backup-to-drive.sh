#!/bin/sh

# Backup Santa's Memory ke Google Drive (via gdrive-folder-sync)
# Run manually: ./backup-to-drive.sh
# Or schedule via cron: 0 2 * * * /root/.openclaw/workspace/backup-to-drive.sh

WORKSPACE="/root/.openclaw/workspace"
BACKUP_DIR="/tmp/santa-backup"
ZIP_FILE="$BACKUP_DIR/santa-memory-$(date +%Y%m%d-%H%M%S).zip"
FOLDER_PATH="/Santa Backup"

echo "🧑🎄 Starting Santa's memory backup..."

# Create backup folder
mkdir -p "$BACKUP_DIR"

# Backup selected files
cd "$WORKSPACE"
tar -czf "$ZIP_FILE" \
  MEMORY.md \
  AGENTS.md \
  USER.md \
  TOOLS.md \
  SOUL.md \
  IDENTITY.md \
  memory/

# Upload to Google Drive
echo "📤 Uploading to Google Drive..."
gdrive-folder-sync "$ZIP_FILE" "$FOLDER_PATH"

# Cleanup
rm -rf "$BACKUP_DIR"
echo "✅ Backup complete!"