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
    """Update hardcoded API key di openclaw.json (misal Google Bearer token)"""
    try:
        cfg = read_json(OPENCLAW_CFG, {})
        cfg_str = json.dumps(cfg)
        if provider == "google":
            # Cari key lama dari auth-profiles agent1
            old_key = get_agent_key("agent1", "google")
            if old_key and old_key != value:
                cfg_str = cfg_str.replace(old_key, value)
                write_json(OPENCLAW_CFG, json.loads(cfg_str))
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
