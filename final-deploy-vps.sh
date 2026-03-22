#!/bin/bash
# Final Safe Deployment Script for VPS
set -e

echo "🧑‍🎄 Final Safe Deployment to VPS"
echo "==================================="
echo ""

# Stop all processes first
echo "🛑 Stopping all OpenClaw processes..."
pkill -9 -f openclaw-gateway || true
sleep 2

# Create backup if needed
echo "📦 Creating backup..."
BACKUP_DIR="/root/.openclaw-backup-safe-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp -a /root/.openclaw/openclaw.json "$BACKUP_DIR/" 2>/dev/null || true
cp -a /root/.openclaw/workspace "$BACKUP_DIR/" 2>/dev/null || true
cp -a /root/.openclaw/agents "$BACKUP_DIR/" 2>/dev/null || true
echo "✅ Backup created at: $BACKUP_DIR"
echo ""

# Extract migration package
echo "📦 Extracting migration package..."
mkdir -p /tmp/openclaw-deploy-final
tar xzf /tmp/openclaw-migration.tar.gz -C /tmp/openclaw-deploy-final

# Create .openclaw if missing
if [ ! -d "/root/.openclaw" ]; then
    mkdir -p /root/.openclaw
fi

# Setup workspace
echo "🏗️ Setting up workspace..."
if [ -d "/tmp/openclaw-deploy-final/workspace" ]; then
    rm -rf /root/.openclaw/workspace
    cp -r /tmp/openclaw-deploy-final/workspace /root/.openclaw/
    echo "✅ Workspace installed"
else
    echo "❌ ERROR: workspace not found in package"
    exit 1
fi

# Create agent directories
echo "👥 Creating agent directories..."
mkdir -p /root/.openclaw/agents/agent1/agent
mkdir -p /root/.openclaw/agents/agent1/sessions
mkdir -p /root/.openclaw/agents/agent2/agent
mkdir -p /root/.openclaw/agents/agent2/sessions
mkdir -p /root/.openclaw/agents/agent3/agent
mkdir -p /root/.openclaw/agents/agent3/sessions
mkdir -p /root/.openclaw/agents/agent4/agent
mkdir -p /root/.openclaw/agents/agent4/sessions
mkdir -p /root/.openclaw/agents/agent5/agent
mkdir -p /root/.openclaw/agents/agent5/sessions
mkdir -p /root/.openclaw/agents/agent6/agent
mkdir -p /root/.openclaw/agents/agent6/sessions
mkdir -p /root/.openclaw/agents/agent7/agent
mkdir -p /root/.openclaw/agents/agent7/sessions
mkdir -p /root/.openclaw/agents/agent8/agent
mkdir -p /root/.openclaw/agents/agent8/sessions
mkdir -p /root/.openclaw/agents/main/agent
mkdir -p /root/.openclaw/agents/main/sessions

echo "✅ Agent directories created"

# Copy agent configs
echo "📋 Installing agent configurations..."
if [ -d "/tmp/openclaw-deploy-final/agents" ]; then
    for i in {1..8}; do
        if [ -d "/tmp/openclaw-deploy-final/agents/agent$i" ]; then
            cp -r /tmp/openclaw-deploy-final/agents/agent$i/agent /root/.openclaw/agents/agent$i/
            echo "  ✅ agent$i"
        fi
    done
fi

# Copy main agent
cp -r /tmp/openclaw-deploy-final/agents/main/agent /root/.openclaw/agents/main/ 2>/dev/null || true

# Create shared memory symlinks
echo "🔗 Setting up shared memory..."
for i in {1..8}; do
    ln -sf /root/.openclaw/workspace/MEMORY.md /root/.openclaw/agents/agent$i/agent/MEMORY.md 2>/dev/null || true
    ln -sf /root/.openclaw/workspace/USER.md /root/.openclaw/agents/agent$i/agent/USER.md 2>/dev/null || true
    ln -sf /root/.openclaw/workspace/TOOLS.md /root/.openclaw/agents/agent$i/agent/TOOLS.md 2>/dev/null || true
    ln -sf /root/.openclaw/workspace/IDENTITY.md /root/.openclaw/agents/agent$i/agent/IDENTITY.md 2>/dev/null || true
    ln -sf /root/.openclaw/workspace/AGENTS.md /root/.openclaw/agents/agent$i/agent/AGENTS.md 2>/dev/null || true
    ln -sf /root/.openclaw/workspace/SOUL.md /root/.openclaw/agents/agent$i/agent/SOUL.md 2>/dev/null || true
done

echo "✅ Shared memory symlinks created"

# Update openclaw.json with migrated configuration
echo "⚙️ Installing configuration..."
if [ -f "/tmp/openclaw-deploy-final/openclaw.json" ]; then
    # Keep existing gateway token if possible
    EXISTING_TOKEN=""
    if [ -f "$BACKUP_DIR/openclaw.json" ]; then
        EXISTING_TOKEN=$(grep -o '"token": "[^"]*"' "$BACKUP_DIR/openclaw.json" | head -1 | cut -d'"' -f4)
    fi

    cp /tmp/openclaw-deploy-final/openclaw.json /root/.openclaw/openclaw.json

    # Restore token if found
    if [ -n "$EXISTING_TOKEN" ]; then
        sed -i "s/\"token\": \"[^\"]*\"/\"token\": \"$EXISTING_TOKEN\"/g" /root/.openclaw/openclaw.json
        echo "  ✅ Gateway token preserved"
    fi

    echo "✅ Configuration installed"
else
    echo "❌ ERROR: openclaw.json not found in package"
    exit 1
fi

# Start gateway
echo ""
echo "🚀 Starting OpenClaw gateway..."
sleep 2

# Try multiple startup methods
if command -v openclaw &> /dev/null; then
    openclaw gateway start
elif command -v npx &> /dev/null; then
    npx openclaw gateway start
else
    echo "⚠️  Neither 'openclaw' nor 'npx' command found, starting manually..."
    cd /root/.openclaw
    node /usr/local/lib/node_modules/openclaw/dist/cli.js gateway start
fi

sleep 3

# Check status
echo ""
echo "🔍 Verifying deployment..."
if ps aux | grep openclaw-gateway | grep -v grep > /dev/null; then
    echo "✅ Gateway is running!"
    echo "   PID: $(pgrep -f openclaw-gateway | head -1)"
else
    echo "❌ WARNING: Gateway not running, check logs:"
    echo "   tail -f /tmp/openclaw/openclaw-$(date +%Y-%m-%d).log"
fi

echo ""
echo "🎉 Deployment complete!"
echo ""
echo "📋 Summary:"
echo "   - Workspace: /root/.openclaw/workspace"
echo "   - Agents: agent1-agent8 + main"
echo "   - Shared memory: enabled"
echo "   - Configuration: updated"
echo ""
echo "⚠️  IMPORTANT Telegram Token Check:"
CURRENT_TOKEN=$(grep -o '"botToken": "[^"]*"' /root/.openclaw/openclaw.json 2>/dev/null | head -1 | cut -d'"' -f4)
if [ -n "$CURRENT_TOKEN" ]; then
    echo "   Current token: ${CURRENT_TOKEN:0:15}..."
    echo ""
    echo "   ⚠️  If you have bots on both servers with the same token, they will conflict!"
    echo "   Only one instance can poll Telegram updates at the same time."
fi

echo ""
echo "🔧 Testing:"
echo "   openclaw status"
echo "   openclaw agents list"
echo ""