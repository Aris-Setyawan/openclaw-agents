# Quick Reference — Multi-Agent Automation System

**Created:** 2026-03-20  
**Purpose:** Fast lookup guide during implementation  

---

## 📚 THE 3 DOCUMENTS

| Document | Size | Purpose | Read First? |
|----------|------|---------|------------|
| **PROJECT_SUMMARY.md** | 12KB | Executive overview, timeline, decisions | ✅ YES |
| **MULTI_AGENT_AUTOMATION_PLAN.md** | 65KB | Full specs, code examples, architecture | ✅ DETAILED |
| **IMPLEMENTATION_STRUCTURE.md** | 21KB | Folder layout, file checklist, workflow | ✅ REFERENCE |

**Total:** 98KB, ~3-4 hours read time

---

## 🎯 THE 3 SYSTEMS

### 1. AUTO-ROUTING ENGINE

**Job:** Classify task → Score agents → Select best

**Core Files:**
- `router/classifier.py` — Detect task type
- `router/scorer.py` — Rank agents (0-1 score)
- `router/router.py` — Make routing decision

**Flow:**
```
request → classify (creative/technical/etc) 
        → build task attributes
        → score candidate agents
        → select primary + fallback
        → return decision
```

**Key Classes:**
- `IntentClassifier` — classify()
- `AgentScorer` — score_agent()
- `AutoRouter` — route()

---

### 2. METRICS & TRACKING

**Job:** Collect execution data → Store → Query → Alert

**Core Files:**
- `metrics/collector.py` — Log executions
- `metrics/store.py` — TimescaleDB storage
- `metrics/alerts.py` — Trigger alerts
- `metrics/notifier.py` — Send notifications

**Flow:**
```
agent execution completes
        → collector.log_execution()
        → extract tokens, calculate cost
        → store in TimescaleDB
        → alerts.check_metric() fires
        → notifier sends alert (if needed)
```

**Key Classes:**
- `MetricsCollector` — log_execution()
- `MetricsStore` — insert_metric(), get_agent_stats()
- `AlertEngine` — check_metric()

---

### 3. DASHBOARD

**Job:** Show costs, alerts, agent performance, budget status

**Core Files:**
- `dashboard/app.py` — Flask server
- `dashboard/routes/*.py` — API endpoints
- `dashboard/services/*.py` — Business logic
- `web/` — React frontend (Phase 2)

**Key Endpoints:**
- `GET /api/metrics/summary` — Cost total, by provider
- `GET /api/cost/breakdown` — Daily/provider breakdown
- `GET /api/alerts` — Active alerts
- `GET /api/budget/status` — Spent vs. limit

---

## 🔄 AGENT SETUP

```
Agent1: Orchestrator (Anthropic Haiku) — Routing & coordination
Agent2: Creative     (DeepSeek Chat)   — Writing & content
Agent3: Analytical   (DeepSeek R1)     — Data analysis & research
Agent4: Technical    (Anthropic Opus)  — Coding & infrastructure
Agent5: Lightweight  (Anthropic Haiku) — Quick tasks
Agent6: General      (ModelStudio 3.5) — All-purpose
Agent7: Chat         (ModelStudio Max) — Conversation
Agent8: Specialized  (ModelStudio Coder) — Code tasks
```

---

## 📊 ROUTING RULES (Quick Reference)

| Task Type | Primary | Fallback | Cost |
|-----------|---------|----------|------|
| Creative (write, social, copy) | Agent2 | Agent1, Agent6 | Medium |
| Analytical (data, research, forecast) | Agent3 | Agent1, Agent6 | Medium |
| Technical (code, debug, deploy) | Agent4 | Agent8, Agent1 | High |
| Technical Specialized (python, JS) | Agent8 | Agent4, Agent1 | Low |
| Chat (discuss, explain) | Agent7 | Agent1, Agent6 | Low |
| Orchestration (coordinate, route) | Agent1 | None (must succeed) | Low |
| General / Unknown | Agent1 | Agent6 | Low |

---

## 💻 CORE DATA STRUCTURES

### TaskAttribute (router/types.py)
```python
@dataclass
class TaskAttribute:
    category: str              # creative, analytical, technical, etc
    complexity: str            # low, medium, high
    cost_sensitive: bool       # true = prefer cheap agents
    requires_reasoning: bool   # true = prefer Agent3
    time_constraint: str       # realtime, normal, background
```

### AgentMetrics (metrics/types.py)
```python
@dataclass
class AgentMetrics:
    agentId: str              # agent1, agent2, etc
    timestamp: str            # ISO8601
    taskId: str
    taskCategory: str
    executionTimeMs: int      # How long task took
    tokensUsed: int           # API tokens consumed
    costUSD: float            # Cost in USD
    successStatus: str        # success, partial, failed
    userRating: int           # 1-5 (optional)
    provider: str             # anthropic, deepseek, modelstudio
    model: str                # Full model name
```

### RoutingDecision (router/types.py)
```python
@dataclass
class RoutingDecision:
    primary_agent: str        # Best choice (e.g., agent2)
    alternate_agents: List    # Fallback options
    rationale: str            # Why this agent
    estimated_cost: float     # Predicted USD cost
    confidence_score: float   # 0-1 (how sure)
```

---

## 🗄️ DATABASE SCHEMA (TimescaleDB)

### Main Table: agent_executions
```sql
CREATE TABLE metrics.agent_executions (
    id BIGSERIAL,
    agent_id VARCHAR(50),          -- agent1, agent2, etc
    task_id VARCHAR(100),          -- unique task identifier
    timestamp TIMESTAMPTZ,         -- execution time
    execution_time_ms INT,         -- how long it took
    tokens_used INT,               -- tokens consumed
    cost_usd NUMERIC(10, 6),       -- cost in USD
    success_status VARCHAR(20),    -- success/failed/partial
    task_category VARCHAR(50),     -- creative/technical/etc
    provider VARCHAR(50),          -- anthropic/deepseek/modelstudio
    model VARCHAR(100),            -- Full model name
    selected_by_router BOOLEAN,    -- Was auto-routed?
    routing_confidence NUMERIC,    -- 0-1
    error_type VARCHAR(200),       -- rate_limit/timeout/etc
    user_rating INT,               -- 1-5 (optional)
    PRIMARY KEY (id, timestamp)
);

-- Converted to hypertable (auto-partitioned by time)
SELECT create_hypertable('metrics.agent_executions', 'timestamp');

-- Indexes for fast queries
CREATE INDEX ON metrics.agent_executions (agent_id, timestamp DESC);
CREATE INDEX ON metrics.agent_executions (provider, timestamp DESC);
CREATE INDEX ON metrics.agent_executions (task_category, timestamp DESC);
```

---

## 📈 KEY METRICS

### Per-Agent Metrics
- **Success Rate** — Successful tasks / Total tasks (%)
- **Avg Latency** — Average execution time (ms)
- **p95 Latency** — 95th percentile latency (ms)
- **Avg Cost** — Total cost / Tasks completed (USD)
- **Throughput** — Tasks per day / hour

### Per-Provider Metrics
- **Total Cost** — Sum of all tasks (USD)
- **Task Count** — How many tasks routed
- **Success Rate** — Successful / Total (%)
- **Error Rate** — Failed / Total (%)

### System Metrics
- **Budget Status** — Spent / Limit (%)
- **Daily Cost** — Today's spend (USD)
- **Cost Trend** — 7-day moving average (USD)
- **Most Used Agent** — Agent with most tasks
- **Cheapest Agent** — Lowest cost per task

---

## 🚨 ALERT TYPES

| Alert | Trigger | Action |
|-------|---------|--------|
| **Budget Threshold** | Spent > 80% of limit | Email + Telegram |
| **Budget Critical** | Spent > 90% of limit | Urgent alert |
| **Cost Spike** | Cost > 2x agent average | Investigate |
| **Error Rate** | Failures > 20% (1h window) | Page + Telegram |
| **Agent Degradation** | Success rate ↓ by 30% | Warn + log |
| **Provider Outage** | All tasks fail for provider | Critical alert |

---

## 🧪 TESTING STRATEGY

### Unit Tests (by module)
- **router/** — 20 tests (classifier, scorer, router)
- **metrics/** — 20 tests (collector, store, alerts)
- **dashboard/** — 10 tests (services, utilities)

### Integration Tests
- **router → metrics flow** — 3 tests
- **database queries** — 4 tests
- **API endpoints** — 5 tests
- **end-to-end scenarios** — 2 tests

**Total:** 64 tests, >80% code coverage

**Run:** `pytest tests/` or `pytest --cov=.`

---

## 🐳 DOCKER QUICK START

```bash
# Build
docker-compose build

# Start all services (TimescaleDB, Redis, API)
docker-compose up -d

# Check logs
docker-compose logs -f backend

# Run migrations
docker-compose exec backend python scripts/migrate_db.py

# Stop
docker-compose down

# Reset database
docker-compose exec backend python scripts/reset_db.py
```

---

## 📋 DEVELOPMENT CHECKLIST (Phase 1)

### Week 1
- [ ] Day 1-2: Docker + Database setup
- [ ] Day 3: Router (classifier + scorer)
- [ ] Day 4: Metrics (collector + store)
- [ ] Day 5: Main router + docs

### Week 2
- [ ] Day 6-7: Alerts + Notifications
- [ ] Day 8-9: Dashboard backend + API
- [ ] Day 10: Tests + Documentation

### Testing
- [ ] 50+ unit/integration tests
- [ ] >80% code coverage
- [ ] All tests passing

### Documentation
- [ ] README.md
- [ ] SETUP.md (step-by-step)
- [ ] API.md (all endpoints)
- [ ] Inline code docs

---

## 🔧 COMMON COMMANDS

```bash
# Python environment
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Testing
pytest tests/                          # Run all
pytest tests/unit/                     # Unit only
pytest tests/integration/              # Integration only
pytest --cov=. tests/                  # With coverage
pytest -v tests/unit/test_router.py    # Single file + verbose

# Code quality
black .                                # Format
mypy . --strict                        # Type check
flake8 .                               # Lint

# Database
python scripts/migrate_db.py           # Create schema
python scripts/seed_test_data.py       # Load test data
python scripts/reset_db.py             # DROP & recreate (CAREFUL!)

# Server
python -m flask run --reload           # Development server
gunicorn dashboard.app:app             # Production

# Docker
docker-compose up -d                   # Start all services
docker-compose down                    # Stop all
docker-compose logs -f backend         # Follow logs
docker-compose exec backend bash       # Shell into backend
```

---

## 📞 FILE LOCATIONS & QUICK EDITS

| Change | File | Section |
|--------|------|---------|
| Add routing rule | `config/routing_rules.yaml` | Add to `rules:` array |
| Change budget limit | `config/settings.py` | `BUDGET_LIMIT_USD = X` |
| Adjust alert threshold | `config/settings.py` | `ALERT_BUDGET_THRESHOLD = X` |
| Add agent | `config/agent_models.yaml` | New entry + pricing |
| Change provider API | `config/providers.yaml` | Update endpoint URL |
| Add test | `tests/unit/test_*.py` | Add `def test_...()` |
| Fix router score | `router/scorer.py` | Adjust weights in `score_agent()` |
| Change cost calculation | `metrics/collector.py` | Edit `_calculate_cost()` |
| Add dashboard endpoint | `dashboard/routes/*.py` | Add `@app.route()` |
| Send alert via Slack | `metrics/notifier.py` | Add Slack client |

---

## 🎓 LEARNING PATH

**If new to this project:**

1. Read **PROJECT_SUMMARY.md** (overview, 15 min)
2. Skim **MULTI_AGENT_AUTOMATION_PLAN.md** Section 2 (routing, 20 min)
3. Review **IMPLEMENTATION_STRUCTURE.md** (folder layout, 10 min)
4. Pick a file from the checklist, implement it
5. Write tests as you go
6. Reference this QUICK_REFERENCE for syntax

---

## 🚦 PHASE 1 SUCCESS CHECKLIST

- [ ] All 30 files created
- [ ] 64 tests passing (>80% coverage)
- [ ] Docker builds & runs
- [ ] Database migrations work
- [ ] Router makes decisions
- [ ] Metrics collected (100+ records)
- [ ] Dashboard shows data
- [ ] Alerts triggered correctly
- [ ] Setup takes <30 min from scratch
- [ ] All docs complete

---

## 💡 COMMON PITFALLS & FIXES

| Issue | Cause | Fix |
|-------|-------|-----|
| Router always picks Agent1 | Classifier returning 'general' | Improve keyword matching |
| No metrics in dashboard | Collector not logging | Check log files, verify DB connection |
| Alerts not firing | Threshold too high | Lower ALERT_THRESHOLD_* in settings |
| DB migration fails | Schema already exists | Run `reset_db.py` first |
| Slow dashboard queries | No indexes | Check indexes created in init-db.sql |
| Docker build fails | Missing dependency | Add to requirements.txt |
| Tests timeout | DB not responding | Run `docker-compose up timescaledb` first |
| Cost calculation wrong | Token extraction failed | Check provider response format |

---

## 📖 WHERE TO FIND THINGS

```
How to...

...route a request?
→ See router/router.py:AutoRouter.route()

...calculate cost?
→ See metrics/collector.py:_calculate_cost()

...add an alert rule?
→ See metrics/alerts.py:AlertEngine.check_metric()

...query metrics from dashboard?
→ See dashboard/services/metrics_service.py

...add a new API endpoint?
→ See dashboard/routes/ (pick a file, add @app.route())

...understand the database?
→ See docker/init-db.sql or IMPLEMENTATION_STRUCTURE.md

...write a test?
→ See tests/conftest.py for fixtures + example in tests/unit/

...configure an agent?
→ See config/agent_models.yaml

...change routing rules?
→ See config/routing_rules.yaml
```

---

## 🎯 PHASE 1 DONE = THIS WORKS

```python
# Create a task request
request = "Write a compelling email for product launch"

# Route it
decision = router.route(request)
# → decision.primary_agent = 'agent2' (correct!)
# → decision.confidence_score = 0.87

# Execute agent (mock)
result = execute_agent(decision.primary_agent, request)

# Log metrics
collector.log_execution(execution_log)

# Check dashboard
GET /api/metrics/summary
# → { totalCost: 8.42, agents: { agent2: { cost: 1.54, ... } } }

# Get alert
GET /api/alerts
# → [] (no issues, budget healthy)
```

**That's the whole loop. Phase 1 makes it work.** 🎄

---

## 🆘 GETTING HELP

**If stuck:**

1. Check relevant spec section in MULTI_AGENT_AUTOMATION_PLAN.md
2. Look at test examples in tests/
3. Check TROUBLESHOOTING in docs/
4. Review IMPLEMENTATION_STRUCTURE.md for file purpose
5. Ask in team Slack/Discord

**If confused about:**
- **Architecture** → Read MULTI_AGENT_AUTOMATION_PLAN.md Section 1-4
- **Code structure** → Read IMPLEMENTATION_STRUCTURE.md
- **Timeline** → Read PROJECT_SUMMARY.md
- **API endpoints** → Will be in docs/API.md (Phase 1 deliverable)

---

**Last Update:** 2026-03-20  
**Status:** Ready to code 🚀

