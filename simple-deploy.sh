#!/bin/bash
# Simple deployment script for VPS
set -e

echo "🧑‍🎄 Simple OpenClaw VPS Deployment"
echo "==================================="

# Check if we have the migration package
if [ ! -f "/tmp/openclaw-migration.tar.gz" ]; then
    echo "❌ Migration package not found!"
    exit 1
fi

# Extract package
echo "📦 Extracting package..."
mkdir -p /tmp/openclaw-migration
tar xzf /tmp/openclaw-migration.tar.gz -C /tmp/openclaw-migration

# Backup existing
echo "📦 Creating backup..."
BACKUP_DIR="/root/.openclaw-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp -a /root/.openclaw/openclaw.json "$BACKUP_DIR/" 2>/dev/null || true
cp -a /root/.openclaw/workspace "$BACKUP_DIR/" 2>/dev/null || true
cp -a /root/.openclaw/agents "$BACKUP_DIR/" 2>/dev/null || true

# Stop gateway
echo "🛑 Stopping gateway..."
pkill -f openclaw-gateway || true
sleep 2

# Restore .openclaw directory if missing
if [ ! -d "/root/.openclaw" ]; then
    echo "⚠️ .openclaw directory missing, creating..."
    mkdir -p /root/.openclaw
fi

# Use the new openclaw.json but preserve gateway auth token
echo "⚙️ Updating configuration..."
if [ -f "/tmp/openclaw-migration/openclaw.json" ]; then
    # Extract gateway token from old config if exists
    OLD_TOKEN=""
    if [ -f "/root/.openclaw/openclaw.json" ]; then
        OLD_TOKEN=$(grep -o '"token": "[^"]*"' /root/.openclaw/openclaw.json | head -1 | cut -d'"' -f4)
    fi
    
    # Copy new config
    cp /tmp/openclaw-migration/openclaw.json /root/.openclaw/openclaw.json
    
    # Restore old token if found
    if [ -n "$OLD_TOKEN" ]; then
        echo "🔑 Preserving gateway auth token..."
        sed -i "s/\"token\": \"[^\"]*\"/\"token\": \"$OLD_TOKEN\"/g" /root/.openclaw/openclaw.json
    fi
    
    # Also preserve port if different
    OLD_PORT=$(grep -o '"port": [0-9]*' /root/.openclaw/openclaw.json.backup 2>/dev/null | head -1 | grep -o '[0-9]*' || echo "18789")
    sed -i "s/\"port\": [0-9]*/\"port\": $OLD_PORT/g" /root/.openclaw/openclaw.json
fi

# Setup workspace
echo "🏗️ Setting up workspace..."
if [ -d "/tmp/openclaw-migration/workspace" ]; then
    rm -rf /root/.openclaw/workspace
    cp -r /tmp/openclaw-migration/workspace /root/.openclaw/
fi

# Create agent directories
echo "👥 Creating agent directories..."
for i in {1..8}; do
    mkdir -p "/root/.openclaw/agents/agent$i"
    mkdir -p "/root/.openclaw/agents/agent$i/agent"
    mkdir -p "/root/.openclaw/agents/agent$i/sessions"
done

# Copy agent configs from package
echo "📋 Copying agent configurations..."
if [ -d "/tmp/openclaw-migration/agents" ]; then
    for i in {1..8}; do
        if [ -d "/tmp/openclaw-migration/agents/agent$i/agent" ]; then
            echo "  Copying agent$i..."
            rm -rf "/root/.openclaw/agents/agent$i/agent"
            cp -r "/tmp/openclaw-migration/agents/agent$i/agent" "/root/.openclaw/agents/agent$i/"
        fi
    done
fi

# Create symlinks for shared memory
echo "🔗 Creating shared memory symlinks..."
for i in {1..8}; do
    ln -sf /root/.openclaw/workspace/MEMORY.md /root/.openclaw/agents/agent$i/agent/MEMORY.md 2>/dev/null || true
    ln -sf /root/.openclaw/workspace/USER.md /root/.openclaw/agents/agent$i/agent/USER.md 2>/dev/null || true
    ln -sf /root/.openclaw/workspace/TOOLS.md /root/.openclaw/agents/agent$i/agent/TOOLS.md 2>/dev/null || true
    ln -sf /root/.openclaw/workspace/IDENTITY.md /root/.openclaw/agents/agent$i/agent/IDENTITY.md 2>/dev/null || true
    ln -sf /root/.openclaw/workspace/AGENTS.md /root/.openclaw/agents/agent$i/agent/AGENTS.md 2>/dev/null || true
    ln -sf /root/.openclaw/workspace/SOUL.md /root/.openclaw/agents/agent$i/agent/SOUL.md 2>/dev/null || true
done

# Start gateway
echo "🚀 Starting gateway..."
openclaw gateway start 2>/dev/null || npx openclaw gateway start 2>/dev/null || true

sleep 2

# Check status
echo "🔍 Checking status..."
if ps aux | grep openclaw-gateway | grep -v grep > /dev/null; then
    echo "✅ Gateway running"
else
    echo "❌ Gateway not running, trying alternative..."
    # Try to run directly
    cd /root/.openclaw && npx openclaw gateway start &
    sleep 3
fi

echo ""
echo "🎉 Deployment complete!"
echo ""
echo "📋 Summary:"
echo "  - Configuration updated"
echo "  - 8 agents created (agent1-agent8)"
echo "  - Workspace transferred"
echo "  - Shared memory symlinks created"
echo ""
echo "⚠️ IMPORTANT: Check Telegram bot token!"
echo "   Current token: $(grep -o '"botToken": "[^"]*"' /root/.openclaw/openclaw.json 2>/dev/null | head -1 | cut -d'"' -f4 | sed 's/./*/10')"
echo ""
echo "To test: openclaw status"