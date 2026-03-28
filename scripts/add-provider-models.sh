#!/bin/bash
# add-provider-models.sh — Tambah/update models untuk provider ke SEMUA tempat yang benar
# Usage: add-provider-models.sh <provider_id> <models_json_file>
#   atau: add-provider-models.sh <provider_id> --from-main  (copy dari main/agent/models.json)
#
# Contoh:
#   add-provider-models.sh sumopod --from-main
#   add-provider-models.sh newprovider /tmp/models.json

set -e

PROVIDER="${1:?Usage: add-provider-models.sh <provider_id> <models_json_file|--from-main>}"
SOURCE="$2"
CFG="/root/.openclaw/openclaw.json"
ALL_AGENTS="agent1 agent2 agent3 agent4 agent5 agent6 agent7 agent8 main"

if [ -z "$SOURCE" ]; then
  echo "ERROR: specify source file or --from-main"
  exit 1
fi

python3 - "$PROVIDER" "$SOURCE" "$CFG" << 'PYEOF'
import json, sys, os

provider = sys.argv[1]
source   = sys.argv[2]
cfg_path = sys.argv[3]
agents   = ["agent1","agent2","agent3","agent4","agent5","agent6","agent7","agent8","main"]

# 1. Read source models
if source == "--from-main":
    src_path = f"/root/.openclaw/agents/main/agent/models.json"
    src = json.load(open(src_path))
    prov_config = src.get("providers", {}).get(provider, {})
    if not prov_config.get("models"):
        print(f"ERROR: main/agent/models.json has no {provider} models")
        sys.exit(1)
else:
    prov_config = json.load(open(source))
    if "models" not in prov_config:
        # Maybe it's a full providers structure
        if "providers" in prov_config and provider in prov_config["providers"]:
            prov_config = prov_config["providers"][provider]
        else:
            print("ERROR: JSON must have 'models' array or 'providers.{provider}' structure")
            sys.exit(1)

models = prov_config.get("models", [])
print(f"Source: {len(models)} {provider} models")

# Validate maxTokens
for m in models:
    if m.get("maxTokens", 1) <= 0:
        m["maxTokens"] = 4096
        print(f"  WARNING: {m['id']} maxTokens was 0, set to 4096")

# 2. Write to openclaw.json
cfg = json.load(open(cfg_path))
cfg.setdefault("models", {}).setdefault("providers", {})[provider] = prov_config
json.dump(cfg, open(cfg_path, "w"), indent=2)
print(f"✅ openclaw.json: {len(models)} {provider} models written")

# 3. Write to ALL agent models.json
for a in agents:
    path = f"/root/.openclaw/agents/{a}/agent/models.json"
    try:
        d = json.load(open(path))
    except:
        d = {"providers": {}}
    d.setdefault("providers", {})[provider] = prov_config
    json.dump(d, open(path, "w"), indent=2)

print(f"✅ All 9 agents: {len(models)} {provider} models propagated")
print(f"\n⚡ Jalankan: openclaw gateway restart")
PYEOF
