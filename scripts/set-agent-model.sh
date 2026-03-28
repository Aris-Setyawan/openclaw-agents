#!/bin/bash
# set-agent-model.sh — Ganti model untuk SATU agent saja (per-agent override)
# Usage: set-agent-model.sh <agent_id> <provider/model> [fallback1] [fallback2]
#
# Contoh:
#   set-agent-model.sh agent1 anthropic/claude-sonnet-4-6
#   set-agent-model.sh agent4 openai/codex-mini-latest modelstudio/qwen3-coder-next
#   set-agent-model.sh agent1 --use-global   (hapus override, ikut global default)

set -e

AGENT_ID="${1:?Usage: set-agent-model.sh <agent_id> <provider/model> [fallback1] [fallback2]}"
MODEL="$2"
FB1="$3"
FB2="$4"
CFG="${OPENCLAW_CFG:-/root/.openclaw/openclaw.json}"

if [ ! -f "$CFG" ]; then
  echo "ERROR: $CFG not found"
  exit 1
fi

python3 - "$AGENT_ID" "$MODEL" "$FB1" "$FB2" "$CFG" << 'PYEOF'
import json, sys

agent_id = sys.argv[1]
model    = sys.argv[2]
fb1      = sys.argv[3]
fb2      = sys.argv[4]
cfg_path = sys.argv[5]

cfg = json.load(open(cfg_path))
agents = cfg.get("agents", {})
raw_list = agents.get("list", [])

# Build map
if isinstance(raw_list, list):
    agents_map = {item["id"]: item for item in raw_list if "id" in item}
else:
    agents_map = raw_list

if agent_id not in agents_map:
    agents_map[agent_id] = {"id": agent_id}

if model == "--use-global":
    # Hapus override → ikut global default
    if "model" in agents_map[agent_id]:
        del agents_map[agent_id]["model"]
    gp = agents.get("defaults", {}).get("model", {}).get("primary", "?")
    print(f"OK: {agent_id} override dihapus → ikut global default ({gp})")
else:
    # Set per-agent override
    agents_map[agent_id]["model"] = {
        "primary": model,
    }
    fallbacks = [f for f in [fb1, fb2] if f]
    if fallbacks:
        agents_map[agent_id]["model"]["fallbacks"] = fallbacks

    print(f"OK: {agent_id} model → {model}")
    if fallbacks:
        print(f"    fallbacks → {fallbacks}")

    # Tampilkan agent lain untuk konfirmasi tidak berubah
    gp = agents.get("defaults", {}).get("model", {}).get("primary", "?")
    print(f"\nAgent lain TIDAK berubah:")
    for aid, acfg in sorted(agents_map.items()):
        if aid == agent_id:
            continue
        m = acfg.get("model", {}).get("primary", "")
        print(f"  {aid}: {m or f'{gp} (global)'}")

# Write back
if isinstance(raw_list, list):
    cfg["agents"]["list"] = list(agents_map.values())
else:
    cfg["agents"]["list"] = agents_map

json.dump(cfg, open(cfg_path, "w"), indent=2)
PYEOF
