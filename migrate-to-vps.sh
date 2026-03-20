#!/bin/bash
# Migrate OpenClaw configuration from current server to VPS
# Usage: SSH to VPS and run this script

set -e

echo "🚀 Starting OpenClaw migration to VPS..."
echo "Current directory: $(pwd)"

# Backup existing config
BACKUP_DIR="/root/.openclaw-backup-$(date +%Y%m%d-%H%M%S)"
echo "📦 Creating backup at: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"
cp -a /root/.openclaw/openclaw.json "$BACKUP_DIR/" 2>/dev/null || true
cp -a /root/.openclaw/workspace "$BACKUP_DIR/" 2>/dev/null || true
cp -a /root/.openclaw/agents "$BACKUP_DIR/" 2>/dev/null || true

# Stop gateway if running
echo "🛑 Stopping OpenClaw gateway..."
pkill -f openclaw-gateway || true
sleep 2

# Create agent directories if not exist
echo "📁 Creating agent directories..."
for i in {1..8}; do
  mkdir -p "/root/.openclaw/agents/agent$i"
  mkdir -p "/root/.openclaw/agents/agent$i/agent"
  mkdir -p "/root/.openclaw/agents/agent$i/sessions"
done

# Create shared workspace structure
echo "🏗️ Setting up shared workspace..."
WORKSPACE="/root/.openclaw/workspace"
mkdir -p "$WORKSPACE/memory"
mkdir -p "$WORKSPACE/diary"
mkdir -p "$WORKSPACE/tasks"
mkdir -p "$WORKSPACE/scripts"

# Copy workspace files from source (this is just template - actual files will be transferred separately)
echo "📋 Creating workspace template files..."

# Create new openclaw.json configuration
echo "⚙️ Generating new openclaw.json..."
cat > /root/.openclaw/openclaw.json << 'EOF'
{
  "meta": {
    "lastTouchedVersion": "2026.3.13",
    "lastTouchedAt": "$(date -Iseconds)"
  },
  "auth": {
    "profiles": {
      "openai-codex:default": {
        "provider": "openai-codex",
        "mode": "oauth"
      },
      "openai:dashscope": {
        "provider": "openai",
        "mode": "token"
      },
      "modelstudio:default": {
        "provider": "modelstudio",
        "mode": "api_key"
      },
      "deepseek:default": {
        "provider": "deepseek",
        "mode": "token"
      },
      "anthropic:default": {
        "provider": "anthropic",
        "mode": "token"
      },
      "openrouter:default": {
        "provider": "openrouter",
        "mode": "api_key"
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "anthropic/claude-opus-4-5"
      },
      "models": {
        "modelstudio/qwen3.5-plus": {
          "alias": "Qwen"
        },
        "modelstudio/qwen3-max-2026-01-23": {},
        "modelstudio/qwen3-coder-next": {},
        "modelstudio/qwen3-coder-plus": {},
        "modelstudio/MiniMax-M2.5": {},
        "modelstudio/glm-5": {},
        "modelstudio/glm-4.7": {},
        "modelstudio/kimi-k2.5": {},
        "anthropic/claude-sonnet-4-6": {
          "alias": "Sonnet"
        },
        "anthropic/claude-opus-4-5": {
          "alias": "Opus45"
        },
        "anthropic/claude-sonnet-4-5": {
          "alias": "Sonnet45"
        },
        "anthropic/claude-opus-4-6": {
          "alias": "Opus"
        },
        "anthropic/claude-haiku-4-5": {
          "alias": "Haiku"
        },
        "deepseek/deepseek-chat": {
          "alias": "DeepSeek"
        },
        "deepseek/deepseek-reasoner": {
          "alias": "R1"
        },
        "openrouter/google/gemini-2.5-flash": {},
        "openrouter/z-ai/glm-4.7-flash": {}
      },
      "workspace": "/root/.openclaw/workspace",
      "compaction": {
        "mode": "safeguard"
      },
      "maxConcurrent": 4,
      "subagents": {
        "maxConcurrent": 8
      },
      "sandbox": {
        "mode": "off"
      }
    },
    "list": [
      {
        "id": "main",
        "default": true,
        "name": "Orchestrator",
        "workspace": "/root/.openclaw/workspace",
        "agentDir": "/root/.openclaw/agents/main/agent",
        "model": "anthropic/claude-opus-4-5"
      },
      {
        "id": "agent1",
        "name": "agent1",
        "workspace": "/root/.openclaw/workspace",
        "agentDir": "/root/.openclaw/agents/agent1/agent",
        "model": {
          "primary": "openrouter/google/gemini-2.5-flash",
          "fallbacks": [
            "deepseek/deepseek-chat",
            "modelstudio/qwen3.5-plus",
            "openrouter/z-ai/glm-4.7-flash"
          ]
        }
      },
      {
        "id": "agent2",
        "name": "agent2",
        "workspace": "/root/.openclaw/workspace",
        "agentDir": "/root/.openclaw/agents/agent2/agent",
        "model": {
          "primary": "deepseek/deepseek-chat",
          "fallbacks": [
            "modelstudio/qwen3.5-plus",
            "openrouter/google/gemini-2.5-flash",
            "anthropic/claude-haiku-4-5"
          ]
        }
      },
      {
        "id": "agent3",
        "name": "agent3",
        "workspace": "/root/.openclaw/workspace",
        "agentDir": "/root/.openclaw/agents/agent3/agent",
        "model": {
          "primary": "deepseek/deepseek-reasoner",
          "fallbacks": [
            "modelstudio/qwen3-max",
            "deepseek/deepseek-chat",
            "openrouter/google/gemini-2.5-flash"
          ]
        }
      },
      {
        "id": "agent4",
        "name": "agent4",
        "workspace": "/root/.openclaw/workspace",
        "agentDir": "/root/.openclaw/agents/agent4/agent",
        "model": {
          "primary": "anthropic/claude-opus-4-6",
          "fallbacks": [
            "anthropic/claude-haiku-4-5",
            "modelstudio/qwen3-coder-next",
            "deepseek/deepseek-chat",
            "openrouter/google/gemini-2.5-flash"
          ]
        }
      },
      {
        "id": "agent5",
        "name": "agent5",
        "workspace": "/root/.openclaw/workspace",
        "agentDir": "/root/.openclaw/agents/agent5/agent",
        "model": {
          "primary": "anthropic/claude-haiku-4-5",
          "fallbacks": [
            "modelstudio/qwen3.5-plus",
            "deepseek/deepseek-chat",
            "openrouter/google/gemini-2.5-flash"
          ]
        }
      },
      {
        "id": "agent6",
        "name": "agent6",
        "workspace": "/root/.openclaw/workspace",
        "agentDir": "/root/.openclaw/agents/agent6/agent",
        "model": {
          "primary": "modelstudio/qwen3.5-plus",
          "fallbacks": [
            "deepseek/deepseek-chat",
            "openrouter/google/gemini-2.5-flash",
            "anthropic/claude-haiku-4-5"
          ]
        }
      },
      {
        "id": "agent7",
        "name": "agent7",
        "workspace": "/root/.openclaw/workspace",
        "agentDir": "/root/.openclaw/agents/agent7/agent",
        "model": {
          "primary": "modelstudio/qwen3-max",
          "fallbacks": [
            "deepseek/deepseek-reasoner",
            "modelstudio/qwen3.5-plus",
            "openrouter/google/gemini-2.5-flash"
          ]
        }
      },
      {
        "id": "agent8",
        "name": "agent8",
        "workspace": "/root/.openclaw/workspace",
        "agentDir": "/root/.openclaw/agents/agent8/agent",
        "model": {
          "primary": "modelstudio/qwen3-coder-next",
          "fallbacks": [
            "modelstudio/qwen3-coder-plus",
            "deepseek/deepseek-chat",
            "anthropic/claude-haiku-4-5"
          ]
        }
      }
    ]
  },
  "tools": {
    "profile": "full",
    "exec": {
      "host": "gateway"
    }
  },
  "channels": {
    "telegram": {
      "enabled": true,
      "dmPolicy": "pairing",
      "botToken": "8746504916:AAF85VqwJPXdJo2qSXP_gYpIbMuHEiboMsE",
      "groupPolicy": "allowlist",
      "streaming": "partial"
    }
  },
  "gateway": {
    "port": 18789,
    "mode": "local",
    "bind": "loopback",
    "auth": {
      "mode": "token",
      "token": "d68a03f1a44a02cd18f8ec28891ac45587c84cd924835023"
    }
  },
  "hooks": {
    "internal": {
      "enabled": true,
      "entries": {
        "boot-md": {
          "enabled": true
        },
        "bootstrap-extra-files": {
          "enabled": true
        },
        "command-logger": {
          "enabled": true
        },
        "session-memory": {
          "enabled": true
        }
      }
    }
  }
}
EOF

echo "✅ Configuration generated"

# Create symlinks for shared memory
echo "🔗 Creating shared memory symlinks..."
for i in {1..8}; do
  ln -sf /root/.openclaw/workspace/MEMORY.md /root/.openclaw/agents/agent$i/agent/MEMORY.md 2>/dev/null || true
  ln -sf /root/.openclaw/workspace/USER.md /root/.openclaw/agents/agent$i/agent/USER.md 2>/dev/null || true
  ln -sf /root/.openclaw/workspace/TOOLS.md /root/.openclaw/agents/agent$i/agent/TOOLS.md 2>/dev/null || true
  ln -sf /root/.openclaw/workspace/IDENTITY.md /root/.openclaw/agents/agent$i/agent/IDENTITY.md 2>/dev/null || true
done

# Create agent-specific files
echo "👤 Creating agent identity files..."
# Copy SOUL.md and AGENTS.md from workspace (will be updated later)
cp -f /root/.openclaw/workspace/SOUL.md /root/.openclaw/agents/agent1/agent/SOUL.md 2>/dev/null || true
cp -f /root/.openclaw/workspace/AGENTS.md /root/.openclaw/agents/agent1/agent/AGENTS.md 2>/dev/null || true

echo "🎉 Migration script ready!"
echo "⚠️ NOTE: API keys need to be manually copied from source server"
echo "⚠️ NOTE: Workspace files (memory/, diary/, tasks/, scripts/) need to be transferred"
echo ""
echo "To start gateway: openclaw gateway start"