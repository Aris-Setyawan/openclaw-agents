# Feature Request: Agent Pair Failover / Agent-Level Redundancy

## Summary
Add support for agent pairing/failover so when a primary agent fails (API timeout, provider down, rate limit), a backup agent automatically takes over.

## Use Case
I have 8 agents configured in pairs for redundancy:

| Primary | Backup | Role |
|---------|--------|------|
| Agent1 (DeepSeek) | Agent5 (Haiku) | Telegram Orchestrator |
| Agent2 (Sonnet) | Agent6 (Qwen) | Creative |
| Agent3 (R1) | Agent7 (Qwen-max) | Analytical |
| Agent4 (Opus) | Agent8 (Qwen-coder) | Technical |

**Current behavior:** When Agent1's provider (e.g., Anthropic) returns 502/503 or times out, the request fails. Other agents don't take over — errors accumulate and user gets no response.

**Desired behavior:** Agent1 fails → automatically route to Agent5 → if Agent5 also fails → try next available agent or return graceful error.

## Proposed Config

```yaml
agents:
  failover:
    enabled: true
    pairs:
      - primary: agent1
        backup: agent5
        # Optional: additional backups
        chain: [agent5, agent6]  
      - primary: agent2
        backup: agent6
    # Global fallback if all paired agents fail
    globalFallback: agent8
    # Retry config
    retryTimeout: 30s
    maxRetries: 2
```

Or simpler version:

```yaml
agents:
  list:
    - id: agent1
      model: deepseek/deepseek-chat
      failoverAgent: agent5  # Simple pairing
```

## Benefits
1. **High availability** — Bot stays responsive even when one provider is down
2. **Cost optimization** — Use cheaper primary, expensive backup only when needed
3. **Load distribution** — Pairs can share workload or take turns
4. **Better UX** — Users don't see "service unavailable" errors

## Current Workaround
Using `openrouter/auto` for provider-level failover, but this doesn't help when:
- The model itself is overloaded
- Need different model characteristics (e.g., reasoning vs speed)
- Want to use different API keys/budgets

## Environment
- OpenClaw version: 2026.3.13
- OS: Linux
- Channel: Telegram

## Additional Context
This is particularly important for chat bots where response time matters. When Anthropic had 502/503 errors today, my Telegram bot was unresponsive for 20+ minutes until manual intervention.

---
Submitted by: @propanhotspot (via Santa 🧑‍🎄)
