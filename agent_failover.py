#!/usr/bin/env python3
"""
OpenClaw Agent Failover & Health Monitor
=========================================
Monitors 8 agents in pairs (1&5, 2&6, 3&7, 4&8).
- Health checks provider endpoints every N seconds
- Auto-failover: agent1 down → route to agent5 → agent6 → etc.
- Auto-recovery: restore original when agent comes back
- Shared memory: writes health state so agents can read it
- Telegram notify on failover/recovery events

Usage:
  python3 agent_failover.py [--config failover_config.json] [--once] [--status]
"""

import json
import os
import sys
import time
import signal
import logging
import argparse
import subprocess
import threading
import http.client
import urllib.parse
from datetime import datetime, timezone
from pathlib import Path
from copy import deepcopy

# ─── Config ──────────────────────────────────────────────────────────────────

CONFIG_FILE = os.path.join(os.path.dirname(__file__), "failover_config.json")

# Agent model definitions (from openclaw.json)
AGENT_MODELS = {
    "agent1": {"model": "openrouter/google/gemini-2.5-flash",   "provider": "openrouter"},
    "agent2": {"model": "deepseek/deepseek-chat",               "provider": "deepseek"},
    "agent3": {"model": "deepseek/deepseek-reasoner",           "provider": "deepseek"},
    "agent4": {"model": "anthropic/claude-opus-4-6",            "provider": "anthropic"},
    "agent5": {"model": "anthropic/claude-haiku-4-5",           "provider": "anthropic"},
    "agent6": {"model": "modelstudio/qwen3.5-plus",             "provider": "modelstudio"},
    "agent7": {"model": "modelstudio/qwen3-max",                "provider": "modelstudio"},
    "agent8": {"model": "modelstudio/qwen3-coder-next",         "provider": "modelstudio"},
}

# Provider health check endpoints (minimal ping)
PROVIDER_HEALTH = {
    "anthropic": {
        "host": "api.anthropic.com",
        "path": "/v1/messages",
        "method": "POST",
        "headers": {
            "x-api-key": os.environ.get("ANTHROPIC_API_KEY", ""),
            "anthropic-version": "2023-06-01",
            "content-type": "application/json",
        },
        "body": json.dumps({
            "model": "claude-haiku-4-5-20251001",
            "max_tokens": 1,
            "messages": [{"role": "user", "content": "ping"}]
        }),
        "success_codes": [200, 400, 401],  # 401 = reachable (auth OK in prod, health-check uses diff key)
        "error_codes": [429, 500, 502, 503, 529],
    },
    "deepseek": {
        "host": "api.deepseek.com",
        "path": "/v1/models",
        "method": "GET",
        "headers": {
            "Authorization": f"Bearer {os.environ.get('DEEPSEEK_API_KEY', 'sk-7f9a50b9c1da48d7b50293d4d75d345e')}",
        },
        "success_codes": [200, 401],
        "error_codes": [500, 502, 503],
    },
    "openrouter": {
        "host": "openrouter.ai",
        "path": "/api/v1/models",
        "method": "GET",
        "headers": {
            "Authorization": f"Bearer {os.environ.get('OPENROUTER_API_KEY', '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')}",
        },
        "success_codes": [200, 401],
        "error_codes": [500, 502, 503],
    },
    "modelstudio": {
        "host": "dashscope.aliyuncs.com",
        "path": "/compatible-mode/v1/models",
        "method": "GET",
        "headers": {
            "Authorization": f"Bearer {os.environ.get('DASHSCOPE_API_KEY', 'sk-10c7a430bc39457ebc312279fcfd66fc')}",
        },
        "success_codes": [200, 401],
        "error_codes": [500, 502, 503],
    },
}

# ─── Logger ──────────────────────────────────────────────────────────────────

def setup_logger(log_file):
    logger = logging.getLogger("failover")
    logger.setLevel(logging.DEBUG)
    fmt = logging.Formatter("%(asctime)s [%(levelname)s] %(message)s", "%Y-%m-%d %H:%M:%S")

    # Console handler only when running interactively (TTY)
    if sys.stderr.isatty():
        ch = logging.StreamHandler()
        ch.setFormatter(fmt)
        logger.addHandler(ch)

    # File handler always (no stdout redirect to avoid duplicates in nohup)
    fh = logging.FileHandler(log_file)
    fh.setFormatter(fmt)
    logger.addHandler(fh)

    return logger

logger = logging.getLogger("failover")


# ─── Health Check ────────────────────────────────────────────────────────────

def check_provider_health(provider: str, timeout: int = 10) -> dict:
    """Test provider API. Returns {ok: bool, code: int, latency_ms: float, error: str}"""
    cfg = PROVIDER_HEALTH.get(provider)
    if not cfg:
        return {"ok": True, "code": 0, "latency_ms": 0, "error": "unknown provider, assuming OK"}

    start = time.time()
    try:
        conn = http.client.HTTPSConnection(cfg["host"], timeout=timeout)
        body = cfg.get("body", "")
        headers = dict(cfg.get("headers", {}))
        if body and "content-type" not in {k.lower() for k in headers}:
            headers["content-type"] = "application/json"

        conn.request(cfg["method"], cfg["path"], body=body or None, headers=headers)
        resp = conn.getresponse()
        code = resp.status
        latency = (time.time() - start) * 1000
        conn.close()

        ok = code in cfg.get("success_codes", [200])
        is_error = code in cfg.get("error_codes", [])

        return {
            "ok": ok and not is_error,
            "code": code,
            "latency_ms": round(latency, 1),
            "error": f"HTTP {code}" if is_error else ""
        }
    except Exception as e:
        latency = (time.time() - start) * 1000
        return {
            "ok": False,
            "code": -1,
            "latency_ms": round(latency, 1),
            "error": str(e)
        }


def check_agent_health(agent_id: str) -> dict:
    """Check health of an agent by checking its provider."""
    info = AGENT_MODELS.get(agent_id, {})
    provider = info.get("provider", "")
    result = check_provider_health(provider)
    result["agent"] = agent_id
    result["provider"] = provider
    result["model"] = info.get("model", "")
    result["checked_at"] = datetime.now(timezone.utc).isoformat()
    return result


# ─── Openclaw Config Management ──────────────────────────────────────────────

def load_openclaw_config(path: str) -> dict:
    with open(path, "r") as f:
        return json.load(f)

def save_openclaw_config(path: str, config: dict):
    # Backup first
    backup = path + ".bak"
    if os.path.exists(path):
        import shutil
        shutil.copy2(path, backup)

    # Update lastTouchedAt
    config.setdefault("meta", {})["lastTouchedAt"] = datetime.now(timezone.utc).isoformat()

    with open(path, "w") as f:
        json.dump(config, f, indent=2)

def get_telegram_binding_agent(config: dict) -> str:
    """Get current agent that handles Telegram."""
    bindings = config.get("bindings", [])
    for b in bindings:
        if b.get("match", {}).get("channel") == "telegram":
            return b.get("agentId", "agent1")
    return "agent1"

def set_telegram_binding_agent(config: dict, agent_id: str) -> dict:
    """Update Telegram binding to use a different agent."""
    config = deepcopy(config)
    bindings = config.get("bindings", [])
    updated = False
    for b in bindings:
        if b.get("match", {}).get("channel") == "telegram":
            b["agentId"] = agent_id
            updated = True
    if not updated:
        bindings.append({"type": "route", "agentId": agent_id, "match": {"channel": "telegram"}})
    config["bindings"] = bindings
    return config

def restart_gateway():
    """Restart the openclaw-gateway process."""
    try:
        result = subprocess.run(
            ["pkill", "-f", "openclaw-gateway"],
            capture_output=True, timeout=5
        )
        time.sleep(3)  # wait for it to die

        # Gateway should auto-restart (managed by openclaw main process)
        # If not, we can start it manually
        logger.info("Gateway restart signal sent")
        return True
    except Exception as e:
        logger.error(f"Failed to restart gateway: {e}")
        return False

def is_gateway_running() -> bool:
    """Check if gateway process is running."""
    try:
        result = subprocess.run(
            ["pgrep", "-f", "openclaw-gateway"],
            capture_output=True, timeout=5
        )
        return result.returncode == 0
    except:
        return False


# ─── Telegram Notification ───────────────────────────────────────────────────

def send_telegram_notify(bot_token: str, chat_id: str, text: str):
    """Send a message via Telegram bot API."""
    try:
        import urllib.request
        url = f"https://api.telegram.org/bot{bot_token}/sendMessage"
        data = json.dumps({
            "chat_id": chat_id,
            "text": text,
            "parse_mode": "HTML"
        }).encode()
        req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
        urllib.request.urlopen(req, timeout=10)
    except Exception as e:
        logger.warning(f"Telegram notify failed: {e}")


# ─── State Management ────────────────────────────────────────────────────────

def load_state(state_file: str) -> dict:
    """Load failover state from disk."""
    if os.path.exists(state_file):
        try:
            with open(state_file, "r") as f:
                return json.load(f)
        except:
            pass
    return {
        "active_agent": "agent1",
        "original_agent": "agent1",
        "agents": {},
        "failover_count": 0,
        "last_updated": None
    }

def save_state(state_file: str, state: dict):
    """Persist state to disk (also write to shared workspace)."""
    state["last_updated"] = datetime.now(timezone.utc).isoformat()
    os.makedirs(os.path.dirname(os.path.abspath(state_file)), exist_ok=True)
    with open(state_file, "w") as f:
        json.dump(state, f, indent=2)


def write_shared_memory(shared_file: str, state: dict):
    """Write health state to shared workspace so agents can read it."""
    os.makedirs(os.path.dirname(os.path.abspath(shared_file)), exist_ok=True)

    # Format for agents to read
    shared = {
        "updated_at": datetime.now(timezone.utc).isoformat(),
        "telegram_active_agent": state.get("active_agent", "agent1"),
        "is_failover_active": state.get("active_agent") != state.get("original_agent"),
        "agents": {
            agent_id: {
                "status": data.get("status", "unknown"),
                "provider": data.get("provider", ""),
                "fail_count": data.get("fail_count", 0),
                "last_ok": data.get("last_ok"),
                "last_check": data.get("last_check"),
            }
            for agent_id, data in state.get("agents", {}).items()
        },
        "pairs": [
            {"primary": "agent1", "backup": "agent5", "role": "Orchestrator"},
            {"primary": "agent2", "backup": "agent6", "role": "Creative"},
            {"primary": "agent3", "backup": "agent7", "role": "Analytical"},
            {"primary": "agent4", "backup": "agent8", "role": "Technical"},
        ]
    }
    with open(shared_file, "w") as f:
        json.dump(shared, f, indent=2)


# ─── Core Failover Logic ─────────────────────────────────────────────────────

class FailoverManager:
    def __init__(self, config_file: str):
        with open(config_file) as f:
            self.cfg = json.load(f)

        self.openclaw_config_path = self.cfg["openclaw_config"]
        self.state_file = self.cfg["state_file"]
        self.shared_memory_file = self.cfg["shared_memory_file"]
        self.check_interval = self.cfg.get("health_check_interval_seconds", 60)
        self.fail_threshold = self.cfg.get("failover_threshold", 2)
        self.recovery_threshold = self.cfg.get("recovery_threshold", 3)
        self.restart_gw = self.cfg.get("restart_gateway_on_failover", True)
        self.notify_tg = self.cfg.get("notify_telegram", True)

        self.state = load_state(self.state_file)
        self._stop = threading.Event()

        # Read Telegram config from openclaw
        self._telegram_token = None
        self._telegram_chat_id = "613802669"  # from allowFrom config
        try:
            oc = load_openclaw_config(self.openclaw_config_path)
            self._telegram_token = oc.get("channels", {}).get("telegram", {}).get("botToken")
        except:
            pass

        logger.info(f"FailoverManager initialized. Active agent: {self.state.get('active_agent')}")

    def stop(self):
        self._stop.set()

    def _get_agent_state(self, agent_id: str) -> dict:
        if agent_id not in self.state["agents"]:
            self.state["agents"][agent_id] = {
                "status": "unknown",
                "fail_count": 0,
                "ok_count": 0,
                "last_ok": None,
                "last_fail": None,
                "last_check": None,
                "provider": AGENT_MODELS.get(agent_id, {}).get("provider", ""),
            }
        return self.state["agents"][agent_id]

    def _update_agent_health(self, agent_id: str, result: dict):
        """Update agent health state based on check result."""
        s = self._get_agent_state(agent_id)
        s["last_check"] = result["checked_at"]
        s["provider"] = result["provider"]

        if result["ok"]:
            s["ok_count"] = s.get("ok_count", 0) + 1
            s["fail_count"] = 0
            s["last_ok"] = result["checked_at"]

            # Recover: needs N consecutive successes
            if s["status"] in ("failed", "degraded"):
                if s["ok_count"] >= self.recovery_threshold:
                    old_status = s["status"]
                    s["status"] = "healthy"
                    logger.info(f"[RECOVERY] {agent_id} recovered after {self.recovery_threshold} checks")
                    return "recovered"
            else:
                s["status"] = "healthy"
        else:
            s["fail_count"] = s.get("fail_count", 0) + 1
            s["ok_count"] = 0
            s["last_fail"] = result["checked_at"]

            if s["fail_count"] >= self.fail_threshold:
                if s["status"] != "failed":
                    s["status"] = "failed"
                    logger.warning(f"[FAILURE] {agent_id}: {result['error']} (fail #{s['fail_count']})")
                    return "failed"
            else:
                s["status"] = "degraded"
                logger.warning(f"[DEGRADED] {agent_id}: {result['error']} (fail #{s['fail_count']}/{self.fail_threshold})")

        return "ok"

    def _find_healthy_agent(self, chain: list) -> str | None:
        """Find first healthy agent in chain."""
        for agent_id in chain:
            s = self._get_agent_state(agent_id)
            if s.get("status") in ("healthy", "unknown"):
                return agent_id
        return None

    def _do_failover(self, failed_agent: str, new_agent: str):
        """Switch Telegram binding from failed to new agent."""
        try:
            config = load_openclaw_config(self.openclaw_config_path)
            current = get_telegram_binding_agent(config)

            if current == new_agent:
                logger.info(f"Already routing to {new_agent}, no change needed")
                return True

            config = set_telegram_binding_agent(config, new_agent)
            save_openclaw_config(self.openclaw_config_path, config)

            self.state["active_agent"] = new_agent
            self.state["failover_count"] = self.state.get("failover_count", 0) + 1

            logger.info(f"[FAILOVER] {failed_agent} → {new_agent} (binding updated)")

            if self.restart_gw:
                logger.info("Restarting gateway...")
                restart_gateway()
                # Wait for gateway to come back up
                for _ in range(15):
                    time.sleep(2)
                    if is_gateway_running():
                        logger.info("Gateway is back online")
                        break
                else:
                    logger.warning("Gateway may not have restarted yet")

            if self.notify_tg and self._telegram_token:
                msg = (
                    f"⚠️ <b>Agent Failover Alert</b>\n\n"
                    f"🔴 <b>{failed_agent}</b> (provider: {AGENT_MODELS.get(failed_agent,{}).get('provider','')}) tidak tersedia\n"
                    f"🟢 Beralih ke <b>{new_agent}</b> (provider: {AGENT_MODELS.get(new_agent,{}).get('provider','')})\n\n"
                    f"Semua request Telegram sekarang dihandle oleh {new_agent}.\n"
                    f"Monitoring terus berjalan untuk recovery otomatis."
                )
                send_telegram_notify(self._telegram_token, self._telegram_chat_id, msg)

            return True
        except Exception as e:
            logger.error(f"Failover failed: {e}")
            return False

    def _do_recovery(self, recovered_agent: str):
        """Restore original agent when it recovers."""
        original = self.state.get("original_agent", "agent1")
        active = self.state.get("active_agent", "agent1")

        if active == original:
            logger.info(f"{recovered_agent} recovered but we're already on original agent")
            return

        if recovered_agent != original:
            logger.info(f"{recovered_agent} recovered but not original agent, skipping restore")
            return

        try:
            config = load_openclaw_config(self.openclaw_config_path)
            config = set_telegram_binding_agent(config, original)
            save_openclaw_config(self.openclaw_config_path, config)
            self.state["active_agent"] = original

            logger.info(f"[RECOVERY] Restored → {original}")

            if self.restart_gw:
                restart_gateway()
                time.sleep(5)

            if self.notify_tg and self._telegram_token:
                msg = (
                    f"✅ <b>Agent Recovery</b>\n\n"
                    f"🟢 <b>{recovered_agent}</b> kembali online\n"
                    f"Routing Telegram dikembalikan ke {original}."
                )
                send_telegram_notify(self._telegram_token, self._telegram_chat_id, msg)
        except Exception as e:
            logger.error(f"Recovery restore failed: {e}")

    def run_once(self):
        """Run one round of health checks across all agents."""
        logger.info("Running health checks...")

        # Check all agents (deduplicate providers for efficiency)
        provider_cache = {}

        for agent_id in AGENT_MODELS:
            provider = AGENT_MODELS[agent_id]["provider"]

            # Use cached result if same provider checked in this round
            if provider in provider_cache:
                result = dict(provider_cache[provider])
                result["agent"] = agent_id
                result["model"] = AGENT_MODELS[agent_id]["model"]
                result["checked_at"] = datetime.now(timezone.utc).isoformat()
            else:
                result = check_agent_health(agent_id)
                provider_cache[provider] = result

            status_sym = "✓" if result["ok"] else "✗"
            logger.info(
                f"  {status_sym} {agent_id:8s} ({provider:12s}) "
                f"HTTP {result['code']:3d} | {result['latency_ms']:6.0f}ms"
                + (f" | ERR: {result['error']}" if not result["ok"] else "")
            )

            event = self._update_agent_health(agent_id, result)

            if event == "failed":
                # Check if this agent is currently the active Telegram handler
                active = self.state.get("active_agent", "agent1")
                if agent_id == active:
                    # Find the failover chain for this agent
                    chain = self._get_failover_chain(agent_id)
                    healthy = self._find_healthy_agent(chain)
                    if healthy and healthy != agent_id:
                        self._do_failover(agent_id, healthy)
                    else:
                        logger.error(f"[CRITICAL] No healthy agents in chain for {agent_id}!")
                        if self.notify_tg and self._telegram_token:
                            send_telegram_notify(
                                self._telegram_token, self._telegram_chat_id,
                                f"🚨 <b>CRITICAL</b>: Semua agent dalam chain tidak tersedia!\n"
                                f"Agen {agent_id} dan backup-nya semua down. Perlu intervensi manual."
                            )

            elif event == "recovered":
                self._do_recovery(agent_id)

        # Write state to files
        save_state(self.state_file, self.state)
        write_shared_memory(self.shared_memory_file, self.state)

        self._print_summary()

    def _get_failover_chain(self, agent_id: str) -> list:
        """Get ordered chain of agents for failover."""
        # Find which pair this agent belongs to
        for pair in self.cfg["pairs"]:
            if pair["primary"] == agent_id or pair["backup"] == agent_id:
                # Start chain from current position
                chain = pair["chain"]
                idx = chain.index(agent_id) if agent_id in chain else 0
                # Rotate chain so current agent is first (skip it, try rest)
                return chain[idx+1:] + chain[:idx]

        # Not in any pair — use global fallback
        return self.cfg.get("global_fallback_chain", ["agent5"])

    def _print_summary(self):
        """Print current health summary."""
        active = self.state.get("active_agent", "agent1")
        original = self.state.get("original_agent", "agent1")
        failover_active = active != original

        print("\n" + "═" * 60)
        print(f"  OPENCLAW AGENT HEALTH SUMMARY  |  {datetime.now().strftime('%H:%M:%S')}")
        print("═" * 60)
        print(f"  Telegram handler: {active}" + (" ← FAILOVER ACTIVE" if failover_active else ""))
        print("─" * 60)
        print(f"  {'AGENT':10} {'PROVIDER':14} {'STATUS':10} {'FAIL':5} {'LATENCY'}")
        print("─" * 60)

        for agent_id, data in sorted(self.state.get("agents", {}).items()):
            status = data.get("status", "unknown")
            sym = {"healthy": "🟢", "failed": "🔴", "degraded": "🟡", "unknown": "⚪"}.get(status, "⚪")
            print(
                f"  {sym} {agent_id:8s}  {data.get('provider',''):12s}  "
                f"{status:10s}  {data.get('fail_count',0):3d}"
            )

        print("═" * 60 + "\n")

    def run_loop(self):
        """Run health check loop indefinitely."""
        logger.info(f"Starting failover monitor (interval: {self.check_interval}s)")

        def handler(sig, frame):
            logger.info("Shutdown signal received")
            self._stop.set()

        signal.signal(signal.SIGTERM, handler)
        signal.signal(signal.SIGINT, handler)

        while not self._stop.is_set():
            try:
                self.run_once()
            except Exception as e:
                logger.error(f"Health check error: {e}")

            if not self._stop.wait(self.check_interval):
                continue

        logger.info("Failover monitor stopped")

    def get_status(self) -> dict:
        """Return current status as dict."""
        state = load_state(self.state_file)
        return {
            "active_agent": state.get("active_agent", "agent1"),
            "original_agent": state.get("original_agent", "agent1"),
            "failover_active": state.get("active_agent") != state.get("original_agent"),
            "failover_count": state.get("failover_count", 0),
            "last_updated": state.get("last_updated"),
            "agents": state.get("agents", {}),
        }


# ─── CLI ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="OpenClaw Agent Failover Monitor")
    parser.add_argument("--config", default=CONFIG_FILE, help="Config file path")
    parser.add_argument("--once", action="store_true", help="Run one health check and exit")
    parser.add_argument("--status", action="store_true", help="Show current status and exit")
    parser.add_argument("--failover", metavar="AGENT", help="Manually force failover to AGENT")
    parser.add_argument("--restore", action="store_true", help="Restore original agent binding")
    args = parser.parse_args()

    # Setup logging
    with open(args.config) as f:
        cfg = json.load(f)
    setup_logger(cfg.get("log_file", "/root/openclaw/failover.log"))

    mgr = FailoverManager(args.config)

    if args.status:
        status = mgr.get_status()
        print(json.dumps(status, indent=2))
        return

    if args.failover:
        logger.info(f"Manual failover to {args.failover}")
        active = mgr.state.get("active_agent", "agent1")
        mgr._do_failover(active, args.failover)
        return

    if args.restore:
        original = mgr.state.get("original_agent", "agent1")
        logger.info(f"Manual restore to {original}")
        config = load_openclaw_config(mgr.openclaw_config_path)
        config = set_telegram_binding_agent(config, original)
        save_openclaw_config(mgr.openclaw_config_path, config)
        mgr.state["active_agent"] = original
        save_state(mgr.state_file, mgr.state)
        if mgr.restart_gw:
            restart_gateway()
        return

    if args.once:
        mgr.run_once()
        return

    mgr.run_loop()


if __name__ == "__main__":
    main()
