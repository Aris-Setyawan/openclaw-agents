#!/usr/bin/env python3
"""
OpenClaw Panel — Flask backend
Port: 7842
Auth: X-Panel-Token header
"""
import json, os, glob, subprocess
from datetime import datetime, timezone
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
ALL_AGENTS = AGENTS + ["main"]

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

def _get_profile_key(profile):
    """Ambil value key dari profile — coba 'key' dulu, lalu 'token'."""
    return profile.get("key") or profile.get("token") or ""

def _set_profile_key(profile, value):
    """Set key value — pakai field 'key' atau 'token' sesuai yg sudah ada."""
    if "token" in profile:
        profile["token"] = value
    else:
        profile["key"] = value

def discover_providers():
    """Discover semua provider dari openclaw.json + auth-profiles. Return dict {name: {models, has_key, key_masked}}."""
    cfg = read_json(OPENCLAW_CFG, {})
    result = {}

    # 1. Dari models.providers di openclaw.json
    for pname, pdata in cfg.get("models", {}).get("providers", {}).items():
        result[pname] = {
            "id": pname,
            "model_count": len(pdata.get("models", [])),
        }

    # 2. Dari auth-profiles agent1 (sumber utama keys)
    d = read_json(auth_profiles_path("agent1"))
    for profile_name, profile in d.get("profiles", {}).items():
        prov = profile_name.split(":")[0]
        if prov not in result:
            result[prov] = {"id": prov, "model_count": 0}
        key_val = _get_profile_key(profile)
        result[prov]["has_key"] = bool(key_val)
        result[prov]["key_masked"] = (key_val[:12]+"..."+key_val[-6:]) if len(key_val) > 18 else ("set" if key_val else "")

    # 3. Juga cek main agent (bisa punya key yg belum di-propagate)
    d_main = read_json(auth_profiles_path("main"))
    for profile_name, profile in d_main.get("profiles", {}).items():
        prov = profile_name.split(":")[0]
        if prov not in result:
            result[prov] = {"id": prov, "model_count": 0}
        if not result[prov].get("has_key"):
            key_val = _get_profile_key(profile)
            if key_val:
                result[prov]["has_key"] = True
                result[prov]["key_masked"] = (key_val[:12]+"..."+key_val[-6:]) if len(key_val) > 18 else ("set" if key_val else "")
                result[prov]["only_in_main"] = True  # belum di-propagate

    return result

def get_agent_key(agent, provider):
    d = read_json(auth_profiles_path(agent))
    profile = d.get("profiles", {}).get(f"{provider}:default", {})
    return _get_profile_key(profile)

def set_agent_key(agent, provider, value):
    """Set key untuk satu agent. Auto-detect key field."""
    path = auth_profiles_path(agent)
    d = read_json(path, {"profiles": {}})
    profile_name = f"{provider}:default"
    if profile_name not in d.setdefault("profiles", {}):
        d["profiles"][profile_name] = {"provider": provider, "type": "api_key"}
    _set_profile_key(d["profiles"][profile_name], value)
    write_json(path, d)

def propagate_key(provider, value):
    """Propagate key ke SEMUA agents (agent1-8 + main)."""
    for agent in ALL_AGENTS:
        try:
            set_agent_key(agent, provider, value)
        except Exception as e:
            print(f"[panel] propagate_key {provider} -> {agent} error: {e}")

# ─────────────────────────────────────────────
@app.route("/api/status")
def api_status():
    health = read_json(HEALTH_FILE, {})

    # Baca model config real-time dari openclaw.json
    cfg = read_json(OPENCLAW_CFG, {})
    agents_section = cfg.get("agents", {})
    global_model = agents_section.get("defaults", {}).get("model", {})
    global_primary = global_model.get("primary", "")
    raw_list = agents_section.get("list", [])
    if isinstance(raw_list, list):
        agents_map = {item["id"]: item for item in raw_list if "id" in item}
    else:
        agents_map = raw_list

    agents_out = []
    for a in AGENTS:
        info = health.get("agents", {}).get(a, {})
        # Model: per-agent override atau global default
        acfg = agents_map.get(a, {})
        model_cfg = acfg.get("model", {})
        current_model = model_cfg.get("primary") or global_primary
        # Provider dari model string (format: "provider/model")
        current_provider = current_model.split("/")[0] if "/" in current_model else info.get("provider", "—")
        agents_out.append({
            "id": a,
            "role": AGENT_ROLES.get(a, ""),
            "status": info.get("status", "unknown"),
            "provider": current_provider,
            "model": current_model,
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

    # Global defaults — sumber kebenaran utama
    agents_section = cfg.get("agents", {})
    global_model = agents_section.get("defaults", {}).get("model", {})
    global_primary   = global_model.get("primary", "")
    global_fallbacks = global_model.get("fallbacks", [])

    # Per-agent overrides di agents.list (opsional, override global)
    raw_list = agents_section.get("list", [])
    if isinstance(raw_list, list):
        agents_map = {item["id"]: item for item in raw_list if "id" in item}
    else:
        agents_map = raw_list

    agents_cfg = []
    extra_models = set()
    for a in AGENTS:
        acfg = agents_map.get(a, {})
        model_cfg = acfg.get("model", {})
        # Per-agent override menang; fallback ke global defaults
        primary   = model_cfg.get("primary")   or global_primary
        fallbacks = model_cfg.get("fallbacks") or global_fallbacks
        for m in [primary] + fallbacks:
            if m and m not in models_list:
                extra_models.add(m)
        agents_cfg.append({
            "id": a,
            "role": AGENT_ROLES.get(a, ""),
            "primary": primary,
            "fallbacks": fallbacks,
            "is_override": bool(model_cfg.get("primary")),  # tandai kalau ada override
        })
    models_list = sorted(extra_models) + models_list

    # Global defaults info untuk panel
    global_cfg = {
        "primary": global_primary,
        "fallbacks": global_fallbacks,
    }

    # Providers + API keys — dynamic discovery
    all_providers = discover_providers()
    keys = {p: info.get("key_masked", "") for p, info in all_providers.items()}
    providers_list = [
        {"id": p, "model_count": info.get("model_count", 0),
         "has_key": info.get("has_key", False),
         "only_in_main": info.get("only_in_main", False)}
        for p, info in sorted(all_providers.items())
    ]

    creative = read_json(CREATIVE_CFG, {
        "image": {"provider": "gemini", "style": "photorealistic"},
        "audio": {"provider": "google", "voice": "Aoede"},
        "video": {"model": "veo-3.0-fast-generate-001", "duration": 6},
    })

    # Web search config
    ws = cfg.get("tools", {}).get("web", {}).get("search", {})
    websearch = {
        "enabled":  ws.get("enabled", False),
        "provider": ws.get("provider", ""),
        "gemini":   {"apiKey": _mask(ws.get("gemini",{}).get("apiKey",""))},
        "brave":    {"apiKey": _mask(ws.get("apiKey","") if ws.get("provider")=="brave" else ws.get("brave",{}).get("apiKey",""))},
        "grok":     {"apiKey": _mask(ws.get("grok",{}).get("apiKey",""))},
        "kimi":     {"apiKey": _mask(ws.get("kimi",{}).get("apiKey",""))},
        "perplexity":{"apiKey": _mask(ws.get("perplexity",{}).get("apiKey",""))},
    }

    return jsonify({
        "models": models_list,
        "agents": agents_cfg,
        "global": global_cfg,
        "providers": providers_list,
        "keys": keys,
        "creative": creative,
        "websearch": websearch,
    })

def _mask(val):
    if not val: return ""
    return (val[:10] + "..." + val[-4:]) if len(val) > 14 else "set"

def update_openclaw_json_key(provider, value):
    """Update API key di SEMUA lokasi openclaw.json untuk provider tertentu."""
    try:
        cfg = read_json(OPENCLAW_CFG, {})
        changed = False

        if provider == "google":
            providers = cfg.get("models", {}).get("providers", {})

            # 1. providers.google.apiKey + headers
            if "google" in providers:
                providers["google"]["apiKey"] = value
                if "headers" in providers["google"]:
                    providers["google"]["headers"]["Authorization"] = f"Bearer {value}"
                changed = True

            # 2. providers.gemini.apiKey (alias)
            if "gemini" in providers:
                providers["gemini"]["apiKey"] = value
                changed = True

            # 3. tools.web.search.gemini.apiKey
            ws = cfg.get("tools", {}).get("web", {}).get("search", {}).get("gemini", {})
            if ws is not None:
                cfg.setdefault("tools", {}).setdefault("web", {}).setdefault("search", {}).setdefault("gemini", {})["apiKey"] = value
                changed = True

            # 4. auth.profiles.google:default — JANGAN tulis key value di sini!
            #    Section ini hanya simpan {provider, mode}, bukan nilai key.
            #    Nilai key ada di per-agent auth-profiles.json (sudah di-propagate via propagate_key)

        else:
            # Provider lain: update apiKey di models.providers jika ada
            prov_cfg = cfg.get("models", {}).get("providers", {}).get(provider, {})
            if prov_cfg and "apiKey" in prov_cfg:
                prov_cfg["apiKey"] = value
                changed = True

        if changed:
            write_json(OPENCLAW_CFG, cfg)
            print(f"[panel] openclaw.json updated for {provider}")
    except Exception as e:
        print(f"[panel] update_openclaw_json_key error: {e}")

@app.route("/api/keys", methods=["POST"])
def api_keys():
    if not auth(request): return jsonify({"error":"unauthorized"}), 401
    data = request.json or {}
    updated = []
    for prov, val in data.items():
        if not val:
            continue
        # Update openclaw.json (misal Google Bearer token)
        update_openclaw_json_key(prov, val)
        # Propagate ke SEMUA agents (agent1-8 + main)
        propagate_key(prov, val)
        updated.append(prov)
    return jsonify({"ok": True, "propagated": updated})

@app.route("/api/agents", methods=["POST"])
def api_agents():
    if not auth(request): return jsonify({"error":"unauthorized"}), 401
    data = request.json or {}

    # Jika ada "global" key → update defaults via openclaw config set (proper channel)
    glb = data.get("global", {})
    if glb.get("primary"):
        subprocess.run(
            ["openclaw", "config", "set", "agents.defaults.model.primary", glb["primary"]],
            capture_output=True, text=True, timeout=10
        )
    if glb.get("fallbacks") is not None:
        import shlex
        fallbacks_json = json.dumps([f for f in glb["fallbacks"] if f])
        subprocess.run(
            ["openclaw", "config", "set", "agents.defaults.model.fallbacks", fallbacks_json],
            capture_output=True, text=True, timeout=10
        )

    # Per-agent overrides (jika ada) → tulis ke agents.list
    agent_items = data.get("agents", [])
    if agent_items:
        cfg = read_json(OPENCLAW_CFG, {})
        raw_list = cfg.get("agents", {}).get("list", [])
        if isinstance(raw_list, list):
            agents_map = {item["id"]: item for item in raw_list if "id" in item}
        else:
            agents_map = raw_list

        for item in agent_items:
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

@app.route("/api/websearch", methods=["GET","POST"])
def api_websearch():
    if request.method == "GET":
        if not auth(request): return jsonify({"error":"unauthorized"}), 401
        cfg = read_json(OPENCLAW_CFG, {})
        ws = cfg.get("tools", {}).get("web", {}).get("search", {})
        return jsonify({
            "enabled":  ws.get("enabled", False),
            "provider": ws.get("provider", ""),
            "gemini":    ws.get("gemini", {}).get("apiKey", ""),
            "brave":     ws.get("apiKey","") if ws.get("provider")=="brave" else ws.get("brave",{}).get("apiKey",""),
            "grok":      ws.get("grok", {}).get("apiKey", ""),
            "kimi":      ws.get("kimi", {}).get("apiKey", ""),
            "perplexity":ws.get("perplexity", {}).get("apiKey", ""),
        })

    if not auth(request): return jsonify({"error":"unauthorized"}), 401
    data = request.json or {}
    cfg = read_json(OPENCLAW_CFG, {})
    cfg.setdefault("tools", {}).setdefault("web", {})
    search = cfg["tools"]["web"].setdefault("search", {})

    if "enabled" in data:
        search["enabled"] = bool(data["enabled"])
    if "provider" in data:
        search["provider"] = data["provider"]

    # Update key sesuai provider
    for prov in ["gemini","grok","kimi","perplexity"]:
        key = data.get(prov, {}).get("apiKey") or data.get(prov+"_key","")
        if key:
            search.setdefault(prov, {})["apiKey"] = key
    if data.get("brave_key") or data.get("brave",{}).get("apiKey"):
        brave_key = data.get("brave_key") or data["brave"]["apiKey"]
        if search.get("provider") == "brave":
            search["apiKey"] = brave_key
        else:
            search.setdefault("brave", {})["apiKey"] = brave_key

    write_json(OPENCLAW_CFG, cfg)
    return jsonify({"ok": True})

# ─────────────────────────────────────────────
# PROVIDER CRUD + TEMPLATES
# ─────────────────────────────────────────────

PROVIDER_TEMPLATES = {
    "openai": {
        "baseUrl": "https://api.openai.com/v1",
        "api": "openai-completions",
        "models": [
            {"id": "gpt-4.1", "name": "GPT-4.1", "reasoning": False,
             "input": ["text","image"], "contextWindow": 1047576, "maxTokens": 32768,
             "cost": {"input": 2, "output": 8, "cacheRead": 0.5, "cacheWrite": 0}},
            {"id": "gpt-4.1-mini", "name": "GPT-4.1 Mini", "reasoning": False,
             "input": ["text","image"], "contextWindow": 1047576, "maxTokens": 16384,
             "cost": {"input": 0.4, "output": 1.6, "cacheRead": 0.1, "cacheWrite": 0}},
            {"id": "o3-mini", "name": "o3-mini", "reasoning": True,
             "input": ["text"], "contextWindow": 200000, "maxTokens": 100000,
             "cost": {"input": 1.1, "output": 4.4, "cacheRead": 0.275, "cacheWrite": 0}},
        ],
    },
    "anthropic": {
        "baseUrl": "https://api.anthropic.com/v1",
        "api": "anthropic",
        "models": [
            {"id": "claude-opus-4-6", "name": "Claude Opus 4.6", "reasoning": True,
             "input": ["text","image"], "contextWindow": 200000, "maxTokens": 32000,
             "cost": {"input": 15, "output": 75, "cacheRead": 1.5, "cacheWrite": 3.75}},
            {"id": "claude-sonnet-4-6", "name": "Claude Sonnet 4.6", "reasoning": True,
             "input": ["text","image"], "contextWindow": 200000, "maxTokens": 16000,
             "cost": {"input": 3, "output": 15, "cacheRead": 0.3, "cacheWrite": 0.75}},
            {"id": "claude-haiku-4-5", "name": "Claude Haiku 4.5", "reasoning": False,
             "input": ["text","image"], "contextWindow": 200000, "maxTokens": 8192,
             "cost": {"input": 0.8, "output": 4, "cacheRead": 0.08, "cacheWrite": 0.2}},
        ],
    },
    "deepseek": {
        "baseUrl": "https://api.deepseek.com/v1",
        "api": "openai-completions",
        "models": [
            {"id": "deepseek-chat", "name": "DeepSeek V3", "reasoning": False,
             "input": ["text"], "contextWindow": 65536, "maxTokens": 8192,
             "cost": {"input": 0.27, "output": 1.1, "cacheRead": 0.07, "cacheWrite": 0}},
            {"id": "deepseek-reasoner", "name": "DeepSeek R1", "reasoning": True,
             "input": ["text"], "contextWindow": 65536, "maxTokens": 8192,
             "cost": {"input": 0.55, "output": 2.19, "cacheRead": 0.14, "cacheWrite": 0}},
        ],
    },
    "google": {
        "baseUrl": "https://generativelanguage.googleapis.com/v1beta",
        "api": "gemini",
        "models": [
            {"id": "gemini-2.5-flash", "name": "Gemini 2.5 Flash", "reasoning": True,
             "input": ["text","image"], "contextWindow": 1048576, "maxTokens": 65536,
             "cost": {"input": 0.15, "output": 0.6, "cacheRead": 0.0375, "cacheWrite": 0}},
            {"id": "gemini-2.5-pro", "name": "Gemini 2.5 Pro", "reasoning": True,
             "input": ["text","image"], "contextWindow": 1048576, "maxTokens": 65536,
             "cost": {"input": 1.25, "output": 10, "cacheRead": 0.3125, "cacheWrite": 0}},
        ],
    },
    "modelstudio": {
        "baseUrl": "https://dashscope-intl.aliyuncs.com/compatible-mode/v1",
        "api": "openai-completions",
        "models": [
            {"id": "qwen3.5-plus", "name": "Qwen 3.5 Plus", "reasoning": False,
             "input": ["text","image"], "contextWindow": 1000000, "maxTokens": 65536,
             "cost": {"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0}},
            {"id": "qwen3-max", "name": "Qwen 3 Max", "reasoning": False,
             "input": ["text"], "contextWindow": 262144, "maxTokens": 65536,
             "cost": {"input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0}},
        ],
    },
    "openrouter": {
        "baseUrl": "https://openrouter.ai/api/v1",
        "api": "openai-completions",
        "models": [
            {"id": "google/gemini-2.5-flash", "name": "Gemini 2.5 Flash (OR)", "reasoning": True,
             "input": ["text","image"], "contextWindow": 1048576, "maxTokens": 65536,
             "cost": {"input": 0.15, "output": 0.6, "cacheRead": 0, "cacheWrite": 0}},
        ],
    },
}

@app.route("/api/providers/templates")
def api_provider_templates():
    if not auth(request): return jsonify({"error":"unauthorized"}), 401
    return jsonify(PROVIDER_TEMPLATES)

@app.route("/api/providers", methods=["GET"])
def api_providers_list():
    """List providers with full model details from openclaw.json."""
    if not auth(request): return jsonify({"error":"unauthorized"}), 401
    cfg = read_json(OPENCLAW_CFG, {})
    providers = cfg.get("models", {}).get("providers", {})
    result = []
    for pname, pdata in sorted(providers.items()):
        result.append({
            "id": pname,
            "baseUrl": pdata.get("baseUrl", ""),
            "api": pdata.get("api", ""),
            "model_count": len(pdata.get("models", [])),
            "models": pdata.get("models", []),
            "headers": pdata.get("headers", {}),
            "apiKey": bool(pdata.get("apiKey")),
        })
    return jsonify(result)

@app.route("/api/providers/add", methods=["POST"])
def api_providers_add():
    if not auth(request): return jsonify({"error":"unauthorized"}), 401
    data = request.json or {}
    pid = data.get("id", "").strip().lower()
    if not pid: return jsonify({"error": "Provider ID required"}), 400

    cfg = read_json(OPENCLAW_CFG, {})
    providers = cfg.setdefault("models", {}).setdefault("providers", {})
    if pid in providers:
        return jsonify({"error": f"Provider '{pid}' already exists"}), 409

    providers[pid] = {
        "baseUrl": data.get("baseUrl", ""),
        "api": data.get("api", "openai-completions"),
        "models": data.get("models", []),
    }
    if data.get("headers"):
        providers[pid]["headers"] = data["headers"]
    if data.get("apiKey"):
        providers[pid]["apiKey"] = data["apiKey"]

    write_json(OPENCLAW_CFG, cfg)
    return jsonify({"ok": True, "id": pid})

@app.route("/api/providers/edit", methods=["POST"])
def api_providers_edit():
    if not auth(request): return jsonify({"error":"unauthorized"}), 401
    data = request.json or {}
    pid = data.get("id", "").strip()
    if not pid: return jsonify({"error": "Provider ID required"}), 400

    cfg = read_json(OPENCLAW_CFG, {})
    providers = cfg.get("models", {}).get("providers", {})
    if pid not in providers:
        return jsonify({"error": f"Provider '{pid}' not found"}), 404

    if "baseUrl" in data:
        providers[pid]["baseUrl"] = data["baseUrl"]
    if "api" in data:
        providers[pid]["api"] = data["api"]
    if "models" in data:
        providers[pid]["models"] = data["models"]
    if "headers" in data:
        providers[pid]["headers"] = data["headers"]
    if "apiKey" in data:
        providers[pid]["apiKey"] = data["apiKey"]

    write_json(OPENCLAW_CFG, cfg)
    return jsonify({"ok": True})

@app.route("/api/providers/delete", methods=["POST"])
def api_providers_delete():
    if not auth(request): return jsonify({"error":"unauthorized"}), 401
    data = request.json or {}
    pid = data.get("id", "").strip()
    if not pid: return jsonify({"error": "Provider ID required"}), 400

    cfg = read_json(OPENCLAW_CFG, {})
    providers = cfg.get("models", {}).get("providers", {})
    if pid not in providers:
        return jsonify({"error": f"Provider '{pid}' not found"}), 404

    del providers[pid]
    write_json(OPENCLAW_CFG, cfg)
    return jsonify({"ok": True})

# ─────────────────────────────────────────────
# SCRIPTS + AGENT DOCS + BINDINGS
# ─────────────────────────────────────────────

SCRIPTS_DIR = "/root/openclaw/scripts"

@app.route("/api/scripts", methods=["GET"])
def api_scripts_list():
    if not auth(request): return jsonify({"error":"unauthorized"}), 401
    scripts = []
    for f in sorted(glob.glob(f"{SCRIPTS_DIR}/*")):
        name = os.path.basename(f)
        try:
            stat = os.stat(f)
            scripts.append({
                "name": name,
                "size": stat.st_size,
                "executable": os.access(f, os.X_OK),
                "modified": datetime.fromtimestamp(stat.st_mtime, tz=timezone.utc).isoformat(),
            })
        except OSError:
            pass
    return jsonify(scripts)

@app.route("/api/scripts/run", methods=["POST"])
def api_scripts_run():
    if not auth(request): return jsonify({"error":"unauthorized"}), 401
    data = request.json or {}
    name = data.get("name", "").strip()
    if not name or "/" in name or ".." in name:
        return jsonify({"error": "Invalid script name"}), 400

    path = os.path.join(SCRIPTS_DIR, name)
    if not os.path.isfile(path):
        return jsonify({"error": f"Script '{name}' not found"}), 404

    try:
        result = subprocess.run(
            ["bash", path], capture_output=True, text=True, timeout=30,
            cwd=SCRIPTS_DIR
        )
        return jsonify({
            "ok": True,
            "stdout": result.stdout[-2000:] if len(result.stdout) > 2000 else result.stdout,
            "stderr": result.stderr[-1000:] if len(result.stderr) > 1000 else result.stderr,
            "returncode": result.returncode,
        })
    except subprocess.TimeoutExpired:
        return jsonify({"error": "Script timeout (30s)"}), 504
    except Exception as e:
        return jsonify({"error": str(e)}), 500

AGENT_DOC_FILES = ["SOUL.md", "TOOLS.md", "IDENTITY.md", "MEMORY.md", "AGENTS.md"]

@app.route("/api/agent-docs", methods=["GET"])
def api_agent_docs():
    if not auth(request): return jsonify({"error":"unauthorized"}), 401
    agent = request.args.get("agent", "agent1")
    if agent not in ALL_AGENTS:
        return jsonify({"error": "Invalid agent"}), 400

    agent_dir = f"{BASE}/agents/{agent}/agent"
    docs = {}
    for fname in AGENT_DOC_FILES:
        fpath = os.path.join(agent_dir, fname)
        try:
            docs[fname] = open(fpath).read()
        except FileNotFoundError:
            docs[fname] = None
    return jsonify({"agent": agent, "docs": docs})

@app.route("/api/agent-docs", methods=["POST"])
def api_agent_docs_save():
    if not auth(request): return jsonify({"error":"unauthorized"}), 401
    data = request.json or {}
    agent = data.get("agent", "")
    if agent not in ALL_AGENTS:
        return jsonify({"error": "Invalid agent"}), 400

    agent_dir = f"{BASE}/agents/{agent}/agent"
    saved = []
    for fname, content in data.get("docs", {}).items():
        if fname not in AGENT_DOC_FILES:
            continue
        fpath = os.path.join(agent_dir, fname)
        try:
            with open(fpath, "w") as f:
                f.write(content)
            saved.append(fname)
        except Exception as e:
            return jsonify({"error": f"Failed to save {fname}: {e}"}), 500
    return jsonify({"ok": True, "saved": saved})

@app.route("/api/bindings")
def api_bindings():
    if not auth(request): return jsonify({"error":"unauthorized"}), 401
    cfg = read_json(OPENCLAW_CFG, {})
    bindings = cfg.get("agents", {}).get("bindings", {})
    return jsonify(bindings)

# ─────────────────────────────────────────────
# SYSTEM ACTIONS
# ─────────────────────────────────────────────

@app.route("/api/health-check", methods=["POST"])
def api_health_check():
    if not auth(request): return jsonify({"error":"unauthorized"}), 401
    try:
        result = subprocess.run(
            ["/root/openclaw/start_failover.sh", "once"],
            capture_output=True, text=True, timeout=60,
            cwd="/root/openclaw"
        )
        health = read_json(HEALTH_FILE, {})
        return jsonify({
            "ok": True,
            "stdout": result.stdout[-2000:],
            "stderr": result.stderr[-500:],
            "health": health,
        })
    except subprocess.TimeoutExpired:
        return jsonify({"error": "Health check timeout (60s)"}), 504
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/api/reload", methods=["POST"])
def api_reload():
    """Reload config — re-read openclaw.json tanpa restart gateway."""
    if not auth(request): return jsonify({"error":"unauthorized"}), 401
    try:
        cfg = read_json(OPENCLAW_CFG, {})
        agent_count = len(cfg.get("agents", {}).get("list", []))
        provider_count = len(cfg.get("models", {}).get("providers", {}))
        return jsonify({
            "ok": True,
            "agents": agent_count,
            "providers": provider_count,
            "message": "Config reloaded successfully",
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/api/gateway/restart", methods=["POST"])
def api_gateway_restart():
    if not auth(request): return jsonify({"error":"unauthorized"}), 401
    try:
        result = subprocess.run(
            ["systemctl", "restart", "openclaw-gateway"],
            capture_output=True, text=True, timeout=15
        )
        if result.returncode != 0:
            return jsonify({"error": f"Restart failed: {result.stderr}"}), 500
        # Check status after restart
        status = subprocess.run(
            ["systemctl", "is-active", "openclaw-gateway"],
            capture_output=True, text=True, timeout=5
        )
        return jsonify({
            "ok": True,
            "status": status.stdout.strip(),
            "message": "Gateway restarted successfully",
        })
    except subprocess.TimeoutExpired:
        return jsonify({"error": "Restart timeout"}), 504
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/api/gateway/status")
def api_gateway_status():
    if not auth(request): return jsonify({"error":"unauthorized"}), 401
    try:
        result = subprocess.run(
            ["systemctl", "status", "openclaw-gateway"],
            capture_output=True, text=True, timeout=5
        )
        active = subprocess.run(
            ["systemctl", "is-active", "openclaw-gateway"],
            capture_output=True, text=True, timeout=5
        )
        return jsonify({
            "status": active.stdout.strip(),
            "details": result.stdout[-1500:],
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/api/config/hash")
def api_config_hash():
    """Lightweight endpoint untuk browser polling — cek apakah config berubah.
    Cek mtime openclaw.json + auth-profiles agent1 + main (catch key changes)."""
    try:
        mtime = os.path.getmtime(OPENCLAW_CFG)
        # Juga cek auth-profiles — key bisa berubah tanpa openclaw.json berubah
        for agent in ["agent1", "main"]:
            try:
                mtime = max(mtime, os.path.getmtime(auth_profiles_path(agent)))
            except OSError:
                pass
        cfg = read_json(OPENCLAW_CFG, {})
        ag = cfg.get("agents", {})
        primary = ag.get("defaults", {}).get("model", {}).get("primary", "")
        fallbacks = ag.get("defaults", {}).get("model", {}).get("fallbacks", [])
        return jsonify({
            "mtime": mtime,
            "primary": primary,
            "fallbacks": fallbacks,
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/api/usage")
def api_usage():
    """Parse token usage + cost dari semua session files agent."""
    stats   = {}   # key = "provider/model"
    img_log = []   # dari api-usage.log
    since_days = int(request.args.get("days", 30))

    # ── 1. Parse session JSONL files ────────────────────────────────────
    for agent in AGENTS:
        pattern = f"{BASE}/agents/{agent}/sessions/*.jsonl"
        for f in glob.glob(pattern):
            try:
                with open(f) as fp:
                    for line in fp:
                        d = json.loads(line)
                        msg = d.get("message", {})
                        if msg.get("role") != "assistant":
                            continue
                        usage = msg.get("usage", {})
                        if not usage:
                            continue
                        inp  = usage.get("input", 0) or 0
                        out  = usage.get("output", 0) or 0
                        total = usage.get("totalTokens", inp + out) or 0
                        cost  = usage.get("cost", {})
                        cost_total = cost.get("total", 0) or 0
                        if total == 0 and cost_total == 0:
                            continue
                        model    = msg.get("model", "unknown")
                        provider = msg.get("provider", "unknown")
                        ts_raw   = d.get("timestamp", "")
                        key = f"{provider}/{model}"
                        if key not in stats:
                            stats[key] = {
                                "provider": provider,
                                "model": model,
                                "input": 0, "output": 0,
                                "cache_read": 0, "cache_write": 0,
                                "total_tokens": 0,
                                "cost_usd": 0.0,
                                "calls": 0,
                                "last_used": "",
                            }
                        stats[key]["input"]       += inp
                        stats[key]["output"]      += out
                        stats[key]["cache_read"]  += usage.get("cacheRead", 0) or 0
                        stats[key]["cache_write"] += usage.get("cacheWrite", 0) or 0
                        stats[key]["total_tokens"]+= total
                        stats[key]["cost_usd"]    += cost_total
                        stats[key]["calls"]       += 1
                        if ts_raw > stats[key]["last_used"]:
                            stats[key]["last_used"] = ts_raw
            except Exception:
                pass

    # ── 2. Parse api-usage.log (image/video generation) ─────────────────
    usage_log = f"{BASE}/workspace/logs/api-usage.log"
    image_count = {}; video_count = {}
    try:
        with open(usage_log) as fp:
            for line in fp:
                parts = [p.strip() for p in line.split("|")]
                if len(parts) < 4:
                    continue
                ts, caller, typ, provider = parts[0], parts[1], parts[2], parts[3]
                if typ == "image":
                    image_count[provider] = image_count.get(provider, 0) + 1
                elif typ == "video":
                    video_count[provider] = video_count.get(provider, 0) + 1
    except Exception:
        pass

    # ── 3. Balance cepat dari check-all-balances.sh ──────────────────────
    balances = {}
    try:
        # DeepSeek balance dari API
        ds_key = ""
        try:
            d = json.load(open(auth_profiles_path("agent1")))
            ds_key = d.get("profiles", {}).get("deepseek:default", {}).get("token", "")
        except Exception:
            pass
        if ds_key:
            r = subprocess.run(
                ["curl", "-s", "https://api.deepseek.com/user/balance",
                 "-H", f"Authorization: Bearer {ds_key}"],
                capture_output=True, text=True, timeout=5
            )
            bd = json.loads(r.stdout)
            bal = bd.get("balance_infos", [{}])[0].get("total_balance", "?")
            balances["deepseek"] = f"${bal}"
    except Exception:
        pass

    # ── 3b. Per-agent breakdown ──────────────────────────────────────────
    agent_stats = {}
    for agent in AGENTS + ["main"]:
        pattern = f"{BASE}/agents/{agent}/sessions/*.jsonl*"
        a = {"id": agent, "total_tokens": 0, "cost_usd": 0.0, "calls": 0,
             "input": 0, "output": 0, "top_model": ""}
        model_cost = {}
        for f in glob.glob(pattern):
            try:
                with open(f) as fp:
                    for line in fp:
                        d = json.loads(line)
                        msg = d.get("message", {})
                        if msg.get("role") != "assistant": continue
                        usage = msg.get("usage", {})
                        if not usage: continue
                        tot  = usage.get("totalTokens", 0) or 0
                        cost = (usage.get("cost", {}) or {}).get("total", 0) or 0
                        inp  = usage.get("input", 0) or 0
                        out  = usage.get("output", 0) or 0
                        if tot == 0 and cost == 0: continue
                        mk = f"{msg.get('provider','?')}/{msg.get('model','?')}"
                        a["total_tokens"] += tot
                        a["cost_usd"]     += cost
                        a["calls"]        += 1
                        a["input"]        += inp
                        a["output"]       += out
                        model_cost[mk] = model_cost.get(mk, 0) + cost
            except: pass
        if model_cost:
            a["top_model"] = max(model_cost, key=model_cost.get)
        if a["calls"] > 0:
            agent_stats[agent] = a

    # ── 4. Daily cost breakdown ───────────────────────────────────────────
    daily = {}
    for agent in AGENTS + ["main"]:
        for f in glob.glob(f"{BASE}/agents/{agent}/sessions/*.jsonl*"):
            try:
                with open(f) as fp:
                    for line in fp:
                        d = json.loads(line)
                        msg = d.get("message", {})
                        if msg.get("role") != "assistant": continue
                        usage = msg.get("usage", {})
                        cost = (usage.get("cost", {}) or {}).get("total", 0) or 0
                        if cost == 0: continue
                        day = d.get("timestamp", "")[:10]
                        if day:
                            daily[day] = daily.get(day, 0) + cost
            except: pass

    # ── 5. Ringkasan total ────────────────────────────────────────────────
    grand_total_tokens = sum(v["total_tokens"] for v in stats.values())
    grand_total_cost   = sum(v["cost_usd"] for v in stats.values())
    rows = sorted(stats.values(), key=lambda x: -x["cost_usd"])

    return jsonify({
        "rows": rows,
        "grand_total_tokens": grand_total_tokens,
        "grand_total_cost": grand_total_cost,
        "image_count": image_count,
        "video_count": video_count,
        "balances": balances,
        "agent_stats": list(agent_stats.values()),
        "daily": [{"date": k, "cost": v} for k, v in sorted(daily.items())],
    })

if __name__ == "__main__":
    print(f"[panel] OpenClaw Panel running on http://0.0.0.0:7842")
    print(f"[panel] Token: {PANEL_TOKEN}")
    app.run(host="0.0.0.0", port=7842, debug=False)
