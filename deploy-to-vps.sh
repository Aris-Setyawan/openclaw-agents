#!/bin/bash
# Deploy OpenClaw configuration from current server to VPS
# This script should be run on the VPS (43.129.53.165)

set -e

echo "🧑‍🎄 OpenClaw VPS Deployment Script"
echo "====================================="

# Check if we're on the VPS
echo "🔍 Checking system..."
HOSTNAME=$(hostname)
echo "Hostname: $HOSTNAME"
echo ""

# Backup existing configuration
echo "📦 Creating backup..."
BACKUP_DIR="/root/.openclaw-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp -a /root/.openclaw/openclaw.json "$BACKUP_DIR/" 2>/dev/null || true
cp -a /root/.openclaw/workspace "$BACKUP_DIR/" 2>/dev/null || true
cp -a /root/.openclaw/agents "$BACKUP_DIR/" 2>/dev/null || true
echo "✅ Backup created at: $BACKUP_DIR"
echo ""

# Stop gateway if running
echo "🛑 Stopping OpenClaw gateway..."
pkill -f openclaw-gateway || true
sleep 3
echo "✅ Gateway stopped"
echo ""

# Extract migration package if exists
if [ -f "/tmp/openclaw-migration.tar.gz" ]; then
    echo "📦 Extracting migration package..."
    mkdir -p /tmp/openclaw-migration
    tar xzf /tmp/openclaw-migration.tar.gz -C /tmp/openclaw-migration
    echo "✅ Package extracted"
    echo ""
fi

# Function to ask for user choice
ask_choice() {
    local prompt="$1"
    local default="$2"
    local choice
    
    read -p "$prompt [$default]: " choice
    echo "${choice:-$default}"
}

# Determine which openclaw.json to use
echo "⚙️ Configuration Selection"
echo "-------------------------"
echo "1. Use configuration from source server (replace completely)"
echo "2. Merge configurations (keep VPS gateway settings, update agents & auth)"
echo "3. Manual review"
echo ""

# For now, we'll use option 2 (merge) as default
CHOICE="2"

if [ "$CHOICE" = "1" ]; then
    echo "🔧 Replacing configuration completely..."
    if [ -f "/tmp/openclaw-migration/openclaw.json" ]; then
        # Keep gateway auth token from existing config for security
        OLD_TOKEN=$(cat /root/.openclaw/openclaw.json 2>/dev/null | grep -o '"token": "[^"]*"' | cut -d'"' -f4 | head -1)
        cp /tmp/openclaw-migration/openclaw.json /root/.openclaw/openclaw.json
        if [ -n "$OLD_TOKEN" ]; then
            echo "Preserving existing gateway auth token..."
            # Simple sed to replace token (this is fragile but works for simple JSON)
            sed -i "s/\"token\": \"[^\"]*\"/\"token\": \"$OLD_TOKEN\"/g" /root/.openclaw/openclaw.json
        fi
        echo "✅ Configuration replaced"
    else
        echo "⚠️ No migration config found, keeping existing"
    fi
elif [ "$CHOICE" = "2" ]; then
    echo "🔧 Merging configurations..."
    echo "⚠️ Note: JSON merge requires jq. Installing jq if needed..."
    
    # Install jq if not present
    if ! command -v jq &> /dev/null; then
        echo "Installing jq..."
        if command -v yum &> /dev/null; then
            yum install -y jq 2>/dev/null || true
        elif command -v dnf &> /dev/null; then
            dnf install -y jq 2>/dev/null || true
        elif command -v apt &> /dev/null; then
            apt update && apt install -y jq 2>/dev/null || true
        fi
    fi
    
    if command -v jq &> /dev/null; then
        echo "✅ jq installed"
        
        # Create merged configuration
        OLD_CONFIG="/root/.openclaw/openclaw.json"
        NEW_CONFIG="/tmp/openclaw-migration/openclaw.json"
        
        if [ -f "$NEW_CONFIG" ]; then
            echo "Merging auth profiles and agents..."
            
            # Create temporary merge script
            cat > /tmp/merge-config.js << 'JSCODE'
const fs = require('fs');
const old = JSON.parse(fs.readFileSync(process.argv[1], 'utf8'));
const new_ = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));

// Preserve gateway settings from old config
const merged = { ...new_ };

// Keep old gateway config (port, auth, bind, etc.)
if (old.gateway) {
    merged.gateway = old.gateway;
}

// Keep old channels config (but update Telegram botToken if in new config)
if (old.channels && old.channels.telegram) {
    if (!merged.channels) merged.channels = {};
    merged.channels.telegram = { ...old.channels.telegram, ...(new_.channels?.telegram || {}) };
}

// Merge auth profiles (prioritize new ones)
if (old.auth && old.auth.profiles) {
    if (!merged.auth) merged.auth = { profiles: {} };
    merged.auth.profiles = { ...old.auth.profiles, ...(new_.auth?.profiles || {}) };
}

// Use new agents list completely
if (new_.agents) {
    merged.agents = new_.agents;
}

// Keep other old settings that don't exist in new
for (const key in old) {
    if (!(key in merged)) {
        merged[key] = old[key];
    }
}

console.log(JSON.stringify(merged, null, 2));
JSCODE
            
            # Check if node is available
            if command -v node &> /dev/null; then
                node /tmp/merge-config.js "$OLD_CONFIG" "$NEW_CONFIG" > /root/.openclaw/openclaw.json.merged
                mv /root/.openclaw/openclaw.json.merged /root/.openclaw/openclaw.json
                echo "✅ Configuration merged using Node.js"
            else
                echo "⚠️ Node.js not available, using simple replacement"
                cp "$NEW_CONFIG" /root/.openclaw/openclaw.json
            fi
        else
            echo "⚠️ No new config found, keeping existing"
        fi
    else
        echo "⚠️ jq not available, using simple replacement"
        if [ -f "/tmp/openclaw-migration/openclaw.json" ]; then
            cp /tmp/openclaw-migration/openclaw.json /root/.openclaw/openclaw.json
        fi
    fi
fi

echo ""

# Setup workspace
echo "🏗️ Setting up workspace..."
if [ -d "/tmp/openclaw-migration/workspace" ]; then
    echo "Copying workspace files..."
    rm -rf /root/.openclaw/workspace
    cp -r /tmp/openclaw-migration/workspace /root/.openclaw/
    echo "✅ Workspace copied"
else
    echo "⚠️ No workspace in migration package"
fi

# Setup agent directories
echo "👥 Setting up agent directories..."
for i in {1..8}; do
    mkdir -p "/root/.openclaw/agents/agent$i"
    mkdir -p "/root/.openclaw/agents/agent$i/agent"
    mkdir -p "/root/.openclaw/agents/agent$i/sessions"
done

# Copy agent configurations from migration package
echo "📋 Copying agent configurations..."
if [ -d "/tmp/openclaw-migration/agents" ]; then
    for i in {1..8}; do
        if [ -d "/tmp/openclaw-migration/agents/agent$i/agent" ]; then
            echo "  Copying agent$i config..."
            rm -rf "/root/.openclaw/agents/agent$i/agent"
            cp -r "/tmp/openclaw-migration/agents/agent$i/agent" "/root/.openclaw/agents/agent$i/"
        fi
    done
fi

# Create shared memory symlinks
echo "🔗 Creating shared memory symlinks..."
for i in {1..8}; do
    ln -sf /root/.openclaw/workspace/MEMORY.md /root/.openclaw/agents/agent$i/agent/MEMORY.md 2>/dev/null || true
    ln -sf /root/.openclaw/workspace/USER.md /root/.openclaw/agents/agent$i/agent/USER.md 2>/dev/null || true
    ln -sf /root/.openclaw/workspace/TOOLS.md /root/.openclaw/agents/agent$i/agent/TOOLS.md 2>/dev/null || true
    ln -sf /root/.openclaw/workspace/IDENTITY.md /root/.openclaw/agents/agent$i/agent/IDENTITY.md 2>/dev/null || true
    ln -sf /root/.openclaw/workspace/AGENTS.md /root/.openclaw/agents/agent$i/agent/AGENTS.md 2>/dev/null || true
    ln -sf /root/.openclaw/workspace/SOUL.md /root/.openclaw/agents/agent$i/agent/SOUL.md 2>/dev/null || true
done

echo "✅ Agent setup complete"
echo ""

# Telegram token note
echo "📱 Telegram Bot Configuration"
echo "-----------------------------"
CURRENT_TOKEN=$(cat /root/.openclaw/openclaw.json 2>/dev/null | grep -o '"botToken": "[^"]*"' | cut -d'"' -f4 | head -1)
if [ -n "$CURRENT_TOKEN" ]; then
    echo "Current bot token: ${CURRENT_TOKEN:0:10}..."
    echo ""
    echo "⚠️ IMPORTANT: If you're running bots on both servers with the same token,"
    echo "   they will conflict! Only one instance can poll Telegram updates."
    echo ""
    echo "Options:"
    echo "1. Use different tokens for each server (recommended)"
    echo "2. Stop bot on this server and use token from source server"
    echo "3. Keep current token"
    echo ""
fi

# Start gateway
echo "🚀 Starting OpenClaw gateway..."
openclaw gateway start 2>/dev/null || echo "⚠️ Failed to start gateway, trying alternative method..."

sleep 2

# Check gateway status
echo "🔍 Checking gateway status..."
if ps aux | grep openclaw-gateway | grep -v grep > /dev/null; then
    echo "✅ Gateway is running"
else
    echo "❌ Gateway failed to start"
    echo "Trying alternative startup..."
    npx openclaw gateway start 2>/dev/null || true
fi

echo ""
echo "🎉 Deployment complete!"
echo ""
echo "📋 Summary:"
echo "  - Configuration updated"
echo "  - 8 agents ready (agent1-agent8)"
echo "  - Shared memory symlinks created"
echo "  - Workspace files transferred"
echo ""
echo "🔧 Next steps:"
echo "  1. Check /root/.openclaw/openclaw.json for correct API keys"
echo "  2. Verify Telegram bot token in channels.telegram.botToken"
echo "  3. Test agents with: openclaw status"
echo ""