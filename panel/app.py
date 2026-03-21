#!/usr/bin/env python3
"""
OpenClaw Panel — Flask backend
Port: 7842
Auth: X-Panel-Token header
"""
import json, os, glob
from datetime import datetime
from flask import Flask, request, jsonify, send_from_directory
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

PANEL_DIR   = os.path.dirname(os.path.abspath(__file__))

BASE_EARLY   = "/root/.openclaw"
TOKEN_FILE   = f"{BASE_EARLY}/panel-token.txt"

def _load_token():
    env = os.environ.get("PANEL_TOKEN")
    if env:
        return env
    try:
        return open(TOKEN_FILE).read().strip() or "openclaw-panel-2026"
    except:
        return "openclaw-panel-2026"

PANEL_TOKEN = _load_token()

@app.route("/")
def index():
    return send_from_directory(PANEL_DIR, "index.html")

BASE         = "/root/.openclaw"
OPENCLAW_CFG = f"{BASE}/openclaw.json"
HEALTH_FILE  = f"{BASE}/workspace/health-state.json"
CREATIVE_CFG = f"{BASE}/workspace/creative-config.json"

AGENTS = ["agent1","agent2","agent3","agent4","agent5","agent6","agent7","agent8"]
AGENT_ROLES = {
    "agent1": "Orchestrator / Telegram",
    "agent2": "Creative (Image, Audio, Video)",
    "agent3": "Analytical / Research",
    "agent4": "Technical / Coding",
    "agent5": "Backup Orchestrator",
    "agent6": "Backup Creative",
    "agent7": "Backup Analytical",
    "agent8": "Backup Technical",
}
PROVIDER_KEYS = {
    "google":      ("google:default",   "key"),
    "openai":      ("openai:default",   "key"),
    "openrouter":  ("openrouter:default","key"),
    "deepseek":    ("deepseek:default", "token"),
    "modelstudio": ("modelstudio:default","key"),
    "anthropic":   ("anthropic:default","token"),
}

def auth(req):
    token = req.headers.get("X-Panel-Token","")
    return token == PANEL_TOKEN

def read_json(path, default=None):
    try:
        return json.load(open(path))
    except:
        return default or {}

def write_json(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    json.dump(data, open(path,"w"), indent=2)

def auth_profiles_path(agent):
    return f"{BASE}/agents/{agent}/agent/auth-profiles.json"

def get_agent_key(agent, provider):
    d = read_json(auth_profiles_path(agent))
    profile_name, key_field = PROVIDER_KEYS.get(provider, (None, None))
    if not profile_name:
        return ""
    return d.get("profiles", {}).get(profile_name, {}).get(key_field, "")

def set_agent_key(agent, provider, value):
    path = auth_profiles_path(agent)
    d = read_json(path, {"profiles": {}})
    profile_name, key_field = PROVIDER_KEYS.get(provider, (None, None))
    if not profile_name:
        return
    if profile_name not in d.setdefault("profiles", {}):
        d["profiles"][profile_name] = {"provider": provider}
    d["profiles"][profile_name][key_field] = value
    write_json(path, d)

# ─────────────────────────────────────────────
@app.route("/api/status")
def api_status():
    health = read_json(HEALTH_FILE, {})
    agents_out = []
    for a in AGENTS:
        info = health.get("agents", {}).get(a, {})
        agents_out.append({
            "id": a,
            "role": AGENT_ROLES.get(a, ""),
            "status": info.get("status", "unknown"),
            "provider": info.get("provider", "—"),
            "last_ok": info.get("last_ok", ""),
            "fail_count": info.get("fail_count", 0),
        })
    return jsonify({
        "agents": agents_out,
        "failover_active": health.get("is_failover_active", False),
        "telegram_active": health.get("telegram_active_agent", "agent1"),
        "updated_at": health.get("updated_at", ""),
    })

@app.route("/api/config")
def api_config():
    cfg = read_json(OPENCLAW_CFG, {})
    providers = cfg.get("models", {}).get("providers", {})
    models_list = []
    for pname, pdata in providers.items():
        for m in pdata.get("models", []):
            models_list.append(f"{pname}/{m['id']}")

    # agents.list bisa array [{id, model, ...}] atau dict {agentId: {...}}
    raw_list = cfg.get("agents", {}).get("list", [])
    if isinstance(raw_list, list):
        agents_map = {item["id"]: item for item in raw_list if "id" in item}
    else:
        agents_map = raw_list

    agents_cfg = []
    for a in AGENTS:
        acfg = agents_map.get(a, {})
        model_cfg = acfg.get("model", {})
        agents_cfg.append({
            "id": a,
            "role": AGENT_ROLES.get(a, ""),
            "primary": model_cfg.get("primary", ""),
            "fallbacks": model_cfg.get("fallbacks", []),
        })

    # API keys (masked)
    keys = {}
    d = read_json(auth_profiles_path("agent1"))
    profiles = d.get("profiles", {})
    for prov, (pname, kf) in PROVIDER_KEYS.items():
        val = profiles.get(pname, {}).get(kf, "")
        keys[prov] = (val[:12] + "..." + val[-6:]) if len(val) > 18 else ("set" if val else "")

    creative = read_json(CREATIVE_CFG, {
        "image": {"provider": "gemini", "style": "photorealistic"},
        "audio": {"provider": "google", "voice": "Aoede"},
        "video": {"model": "veo-3.0-fast-generate-001", "duration": 6},
    })

    return jsonify({
        "models": models_list,
        "agents": agents_cfg,
        "keys": keys,
        "creative": creative,
    })

@app.route("/api/keys", methods=["POST"])
def api_keys():
    if not auth(request): return jsonify({"error":"unauthorized"}), 401
    data = request.json or {}
    for prov, val in data.items():
        if val and prov in PROVIDER_KEYS:
            for a in AGENTS:
                try: set_agent_key(a, prov, val)
                except: pass
    return jsonify({"ok": True})

@app.route("/api/agents", methods=["POST"])
def api_agents():
    if not auth(request): return jsonify({"error":"unauthorized"}), 401
    data = request.json or {}
    cfg = read_json(OPENCLAW_CFG, {})
    raw_list = cfg.get("agents", {}).get("list", [])

    # Build map untuk update
    if isinstance(raw_list, list):
        agents_map = {item["id"]: item for item in raw_list if "id" in item}
    else:
        agents_map = raw_list

    for item in data.get("agents", []):
        aid = item.get("id")
        if not aid: continue
        if aid not in agents_map:
            agents_map[aid] = {"id": aid}
        agents_map[aid].setdefault("model", {})
        if item.get("primary"):
            agents_map[aid]["model"]["primary"] = item["primary"]
        fallbacks = [f for f in item.get("fallbacks", []) if f]
        if fallbacks:
            agents_map[aid]["model"]["fallbacks"] = fallbacks

    # Tulis kembali sesuai format asli
    if isinstance(raw_list, list):
        cfg["agents"]["list"] = list(agents_map.values())
    else:
        cfg["agents"]["list"] = agents_map

    write_json(OPENCLAW_CFG, cfg)
    return jsonify({"ok": True})

@app.route("/api/token", methods=["POST"])
def api_token():
    global PANEL_TOKEN
    if not auth(request): return jsonify({"error": "unauthorized"}), 401
    data = request.json or {}
    new_token = data.get("token", "").strip()
    if not new_token or len(new_token) < 8:
        return jsonify({"error": "Token minimal 8 karakter"}), 400
    PANEL_TOKEN = new_token
    os.makedirs(BASE_EARLY, exist_ok=True)
    open(TOKEN_FILE, "w").write(new_token)
    return jsonify({"ok": True})

@app.route("/api/creative", methods=["POST"])
def api_creative():
    if not auth(request): return jsonify({"error":"unauthorized"}), 401
    data = request.json or {}
    current = read_json(CREATIVE_CFG, {})
    current.update(data)
    write_json(CREATIVE_CFG, current)
    return jsonify({"ok": True})

if __name__ == "__main__":
    print(f"[panel] OpenClaw Panel running on http://0.0.0.0:7842")
    print(f"[panel] Token: {PANEL_TOKEN}")
    app.run(host="0.0.0.0", port=7842, debug=False)
