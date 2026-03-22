#!/bin/bash
# Transfer API Keys from current server to VPS
set -e

echo "🔑 Transfer API Keys to VPS"
echo "============================="

# Create temporary directory for keys
KEY_DIR="/tmp/openclaw-keys-$(date +%s)"
mkdir -p "$KEY_DIR"

# Copy auth profiles from main agent
echo "📋 Copying auth profiles..."
cp /root/.openclaw/agents/main/agent/auth-profiles.json "$KEY_DIR/auth-profiles-main.json"

# Copy models.json
echo "📋 Copying models.json..."
cp /root/.openclaw/agents/main/agent/models.json "$KEY_DIR/models-main.json" 2>/dev/null || true

# Create consolidated auth file with ModelStudio key
echo "🔧 Creating consolidated auth file..."
cat > "$KEY_DIR/auth-profiles-consolidated.json" << 'EOF'
{
  "version": 1,
  "profiles": {
    "anthropic:default": {
      "type": "token",
      "provider": "anthropic",
      "token": "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"
    },
    "openrouter:default": {
      "type": "api_key",
      "provider": "openrouter",
      "key": "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"
    },
    "deepseek:default": {
      "type": "token",
      "provider": "deepseek",
      "token": "sk-7f9a50b9c1da48d7b50293d4d75d345e"
    },
    "modelstudio:default": {
      "type": "api_key",
      "provider": "modelstudio",
      "key": "sk-10c7a430bc39457ebc312279fcfd66fc"
    }
  },
  "lastGood": {
    "anthropic": "anthropic:default",
    "openrouter": "openrouter:default",
    "deepseek": "deepseek:default",
    "modelstudio": "modelstudio:default"
  }
}
EOF

echo "✅ Keys prepared in: $KEY_DIR"
echo ""
echo "📋 Keys summary:"
echo "  - Anthropic: ✅"
echo "  - OpenRouter: ✅"
echo "  - DeepSeek: ✅"
echo "  - ModelStudio: ✅"
echo ""
echo "🔧 To deploy to VPS, run:"
echo "   SSHPASS='shadow-94%-nebula' sshpass -e scp -o StrictHostKeyChecking=no $KEY_DIR/auth-profiles-consolidated.json root@43.129.53.165:/tmp/"
echo ""
echo "Then on VPS:"
echo "   cp /tmp/auth-profiles-consolidated.json /root/.openclaw/agents/main/agent/auth-profiles.json"
echo "   cp /tmp/auth-profiles-consolidated.json /root/.openclaw/agents/agent1/agent/auth-profiles.json"
echo "   ... (copy to all agents)"