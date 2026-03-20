# Implementation Structure — Code Organization & Files

**Created:** 2026-03-20  
**Phase:** 1 (Foundation)  
**Purpose:** Ready-to-code directory layout & file-by-file checklist

---

## 📁 COMPLETE FOLDER STRUCTURE

```
multi-agent-automation/
│
├── README.md                         # Project overview
├── setup.py                          # Package setup
├── requirements.txt                  # Python dependencies
├── .gitignore
├── .env.example                      # Environment template
│
├── config/                           # Configuration files
│   ├── __init__.py
│   ├── settings.py                   # Python config (pydantic)
│   ├── routing_rules.yaml            # Auto-routing rules
│   ├── alert_rules.yaml              # Alert thresholds
│   ├── agent_models.yaml             # Agent → Model mapping
│   └── providers.yaml                # Provider API endpoints
│
├── router/                           # Auto-routing engine
│   ├── __init__.py
│   ├── router.py                     # AutoRouter (main)
│   ├── classifier.py                 # Intent classification
│   ├── scorer.py                     # Agent scoring
│   ├── rules_engine.py               # Rule matching
│   └── types.py                      # Dataclasses (TaskAttribute, etc)
│
├── metrics/                          # Metrics collection & storage
│   ├── __init__.py
│   ├── collector.py                  # MetricsCollector
│   ├── store.py                      # MetricsStore (TimescaleDB)
│   ├── alerts.py                     # AlertEngine
│   ├── notifier.py                   # Telegram/Email notifications
│   └── types.py                      # Dataclasses (AgentMetrics, etc)
│
├── dashboard/                        # Web API backend
│   ├── __init__.py
│   ├── app.py                        # Flask/FastAPI server
│   ├── routes/
│   │   ├── __init__.py
│   │   ├── metrics.py                # GET /api/metrics/*
│   │   ├── cost.py                   # GET /api/cost/*
│   │   ├── alerts.py                 # GET/POST /api/alerts/*
│   │   ├── budget.py                 # GET /api/budget/*
│   │   └── health.py                 # GET /api/health
│   │
│   ├── services/
│   │   ├── __init__.py
│   │   ├── metrics_service.py        # Business logic for metrics
│   │   ├── cost_service.py           # Cost calculation & trends
│   │   ├── budget_service.py         # Budget tracking
│   │   ├── alert_service.py          # Alert management
│   │   └── agent_service.py          # Agent performance data
│   │
│   ├── models/
│   │   ├── __init__.py
│   │   └── schemas.py                # Pydantic request/response models
│   │
│   ├── middleware/
│   │   ├── __init__.py
│   │   ├── auth.py                   # Auth middleware (Phase 3)
│   │   ├── error_handler.py          # Global error handling
│   │   └── logger.py                 # Request logging
│   │
│   └── utils/
│       ├── __init__.py
│       └── cache.py                  # Redis caching
│
├── web/                              # Frontend (React/Vue - Phase 2)
│   ├── index.html
│   ├── package.json
│   ├── vite.config.ts                # (if using Vite)
│   ├── tsconfig.json
│   ├── src/
│   │   ├── App.tsx
│   │   ├── main.tsx
│   │   ├── pages/
│   │   │   ├── Dashboard.tsx         # Main dashboard
│   │   │   ├── CostBreakdown.tsx
│   │   │   ├── AgentPerformance.tsx
│   │   │   ├── BudgetStatus.tsx
│   │   │   └── Alerts.tsx
│   │   ├── components/
│   │   │   ├── CostChart.tsx
│   │   │   ├── AlertsList.tsx
│   │   │   ├── Leaderboard.tsx
│   │   │   ├── MetricCard.tsx
│   │   │   ├── TrendChart.tsx
│   │   │   └── Layout.tsx
│   │   ├── api/
│   │   │   ├── client.ts             # Axios API client
│   │   │   └── types.ts              # Typescript interfaces
│   │   ├── hooks/
│   │   │   ├── useMetrics.ts
│   │   │   ├── useWebSocket.ts       # Real-time updates
│   │   │   └── useBudget.ts
│   │   └── utils/
│   │       └── formatters.ts         # Currency, time formatting
│   │
│   └── public/
│       └── favicon.ico
│
├── scripts/                          # Utility scripts
│   ├── migrate_db.py                 # Create TimescaleDB schema
│   ├── init_router.py                # Initialize router
│   ├── init_metrics.py               # Initialize metrics store
│   ├── check_health.py               # System health check
│   ├── seed_test_data.py             # Create test metrics
│   ├── reset_db.py                   # DANGEROUS: Drop & recreate
│   └── dev_server.sh                 # Development server starter
│
├── docker/                           # Containerization
│   ├── Dockerfile                    # Main app container
│   ├── Dockerfile.web                # Web frontend container (Phase 2)
│   ├── docker-compose.yml            # All services
│   ├── docker-compose.dev.yml        # Development override
│   ├── init-db.sql                   # TimescaleDB schema
│   └── nginx.conf                    # Reverse proxy (Phase 2)
│
├── tests/                            # Unit & integration tests
│   ├── __init__.py
│   ├── conftest.py                   # Pytest fixtures & config
│   │
│   ├── unit/
│   │   ├── test_router.py
│   │   ├── test_classifier.py
│   │   ├── test_scorer.py
│   │   ├── test_metrics_collector.py
│   │   └── test_alerts.py
│   │
│   ├── integration/
│   │   ├── test_router_integration.py
│   │   ├── test_metrics_store.py
│   │   ├── test_dashboard_api.py
│   │   └── test_end_to_end.py
│   │
│   └── fixtures/
│       ├── sample_requests.json       # Test request data
│       └── mock_responses.json        # Mock provider responses
│
├── docs/                             # Documentation
│   ├── ARCHITECTURE.md               # System design deep-dive
│   ├── API.md                        # API endpoint reference
│   ├── SETUP.md                      # Installation & setup
│   ├── USAGE.md                      # How to use the system
│   ├── CONFIGURATION.md              # Config file reference
│   ├── TROUBLESHOOTING.md            # Common issues
│   └── CONTRIBUTING.md               # Dev guidelines
│
├── logs/                             # Log directory (created at runtime)
│   ├── router.log
│   ├── metrics.log
│   └── dashboard.log
│
├── data/                             # Data directory (created at runtime)
│   └── .gitkeep
│
└── .github/                          # GitHub workflows (Phase 2+)
    └── workflows/
        └── ci.yml                    # CI/CD pipeline
```

---

## 📋 FILE-BY-FILE CHECKLIST (PHASE 1)

### Core Application Files

#### 1. **config/settings.py**
```python
# Configuration management with Pydantic
# Features:
#   - Load from .env
#   - Database URL
#   - API keys (Anthropic, DeepSeek, ModelStudio)
#   - Agent definitions
#   - Pricing data
#   - Alert thresholds
#
# Checklist:
# [ ] Create BaseSettings class
# [ ] Add all env vars
# [ ] Add agent definitions
# [ ] Add pricing tiers
# [ ] Add default alert thresholds
# [ ] Add logging config
```

#### 2. **config/routing_rules.yaml**
```yaml
# Routing rules for auto-routing
# Content from MULTI_AGENT_AUTOMATION_PLAN.md Section 2.2
#
# Checklist:
# [ ] Copy rules from plan
# [ ] Add all 10+ rule definitions
# [ ] Define cost_tiers
# [ ] Add priority_overrides
# [ ] Validate YAML syntax
```

#### 3. **router/types.py**
```python
# Dataclasses for routing
# Checklist:
# [ ] TaskAttribute
# [ ] RoutingDecision
# [ ] ClassificationResult
# [ ] TaskCategory enum
```

#### 4. **router/classifier.py**
```python
# Intent classification logic
# Checklist:
# [ ] IntentClassifier class
# [ ] classify() method (keyword-based MVP)
# [ ] _estimate_complexity()
# [ ] KEYWORDS dict (all categories)
# [ ] Unit tests
```

#### 5. **router/scorer.py**
```python
# Agent scoring & ranking
# Checklist:
# [ ] AgentScorer class
# [ ] score_agent() method
# [ ] _score_capability()
# [ ] _score_performance()
# [ ] _score_cost()
# [ ] CAPABILITY_RATINGS
# [ ] COST_TIERS
# [ ] Unit tests
```

#### 6. **router/router.py**
```python
# Main routing orchestrator
# Checklist:
# [ ] AutoRouter class
# [ ] route() main method
# [ ] _get_rules_for_category()
# [ ] _extract_time_constraint()
# [ ] _estimate_cost()
# [ ] Logging integration
# [ ] Integration tests
```

#### 7. **metrics/types.py**
```python
# Dataclasses for metrics
# Checklist:
# [ ] ExecutionLog
# [ ] AgentMetrics
# [ ] AggregatedMetrics
# [ ] DashboardMetrics
# [ ] Alert
# [ ] All with proper typing
```

#### 8. **metrics/collector.py**
```python
# Metrics collection from execution logs
# Checklist:
# [ ] MetricsCollector class
# [ ] log_execution() method
# [ ] _extract_tokens() (all 3 providers)
# [ ] _calculate_cost()
# [ ] _classify_error()
# [ ] Proper error handling
# [ ] Unit tests
```

#### 9. **metrics/store.py**
```python
# TimescaleDB metrics storage
# Checklist:
# [ ] MetricsStore class
# [ ] insert_metric()
# [ ] get_agent_stats()
# [ ] get_provider_stats()
# [ ] get_monthly_spend()
# [ ] Query optimization (indexes)
# [ ] Connection pooling
# [ ] Unit tests
```

#### 10. **metrics/alerts.py**
```python
# Alert engine & management
# Checklist:
# [ ] AlertEngine class
# [ ] check_metric()
# [ ] create_alert()
# [ ] _check_cost_spike()
# [ ] _check_error_rate()
# [ ] _check_budget_threshold()
# [ ] AlertStore integration
# [ ] Unit tests
```

#### 11. **metrics/notifier.py**
```python
# Alert notifications (Telegram, email)
# Checklist:
# [ ] AlertNotifier class
# [ ] send_alert() method
# [ ] Telegram bot integration
# [ ] Email support (optional)
# [ ] Retry logic
# [ ] Rate limiting
# [ ] Unit tests
```

#### 12. **dashboard/app.py**
```python
# Flask/FastAPI server
# Checklist:
# [ ] Create Flask app
# [ ] Register blueprints (routes)
# [ ] Add CORS support
# [ ] Add health check endpoint
# [ ] Add error handlers
# [ ] Add logging
# [ ] Proper shutdown hooks
```

#### 13. **dashboard/routes/metrics.py**
```python
# Metrics API endpoints
# GET /api/metrics/summary
# GET /api/metrics/agents/{agent_id}
# GET /api/metrics/agents
# GET /api/metrics/providers
# Checklist:
# [ ] All endpoints implemented
# [ ] Query parameters (period, agent_id, etc)
# [ ] Response validation
# [ ] Error handling
# [ ] Integration tests
```

#### 14. **dashboard/routes/cost.py**
```python
# Cost tracking endpoints
# GET /api/cost/breakdown
# GET /api/cost/trend
# GET /api/cost/by-agent
# GET /api/cost/by-provider
# Checklist:
# [ ] All endpoints implemented
# [ ] Time-series data handling
# [ ] Aggregation logic
# [ ] Response schemas
# [ ] Tests
```

#### 15. **dashboard/routes/alerts.py**
```python
# Alert management endpoints
# GET /api/alerts
# POST /api/alerts/{id}/acknowledge
# GET /api/alerts/active
# Checklist:
# [ ] All endpoints implemented
# [ ] Alert filtering
# [ ] Acknowledge logic
# [ ] Tests
```

#### 16. **dashboard/routes/budget.py**
```python
# Budget tracking endpoints
# GET /api/budget/status
# GET /api/budget/monthly
# Checklist:
# [ ] Budget calculation
# [ ] Monthly spend tracking
# [ ] Alert thresholds
# [ ] Tests
```

#### 17. **dashboard/services/metrics_service.py**
```python
# Business logic for metrics
# Checklist:
# [ ] get_system_summary()
# [ ] get_agent_stats()
# [ ] get_provider_breakdown()
# [ ] Caching layer
# [ ] Data normalization
```

#### 18. **dashboard/services/cost_service.py**
```python
# Cost calculations & trends
# Checklist:
# [ ] calculate_daily_costs()
# [ ] get_cost_trends()
# [ ] get_cost_by_category()
# [ ] Cost projection
# [ ] Tests
```

#### 19. **docker/Dockerfile**
```dockerfile
# Container for backend
# Checklist:
# [ ] Python 3.10+ base
# [ ] Install requirements
# [ ] Copy source code
# [ ] Set working directory
# [ ] Expose port 5000
# [ ] Health check
# [ ] Non-root user
```

#### 20. **docker/docker-compose.yml**
```yaml
# All services together
# Checklist:
# [ ] timescaledb service
# [ ] redis service (optional)
# [ ] backend service
# [ ] Volume mounts
# [ ] Environment variables
# [ ] Depends_on constraints
# [ ] Health checks
```

#### 21. **docker/init-db.sql**
```sql
# TimescaleDB schema
# Content from MULTI_AGENT_AUTOMATION_PLAN.md Section 5.4
# Checklist:
# [ ] Create metrics table
# [ ] Create hypertable
# [ ] Add indexes
# [ ] Create alerts table
# [ ] Create budget table
# [ ] Retention policies
# [ ] Test with docker-compose
```

#### 22. **scripts/migrate_db.py**
```python
# Database setup script
# Checklist:
# [ ] Connect to PostgreSQL
# [ ] Create extensions
# [ ] Run schema.sql
# [ ] Create indexes
# [ ] Set up partitioning
# [ ] Verify success
```

#### 23. **tests/conftest.py**
```python
# Pytest configuration & fixtures
# Checklist:
# [ ] Database fixtures (test DB)
# [ ] Mock MetricsStore
# [ ] Mock AlertEngine
# [ ] Sample data fixtures
# [ ] Flask test client
# [ ] Cleanup after tests
```

#### 24. **tests/unit/test_router.py**
```python
# Unit tests for router
# Checklist:
# [ ] test_classify_creative_task
# [ ] test_classify_technical_task
# [ ] test_score_by_capability
# [ ] test_score_by_cost
# [ ] test_routing_decision
# [ ] test_time_constraint_detection
# [ ] ~15-20 tests total
```

#### 25. **tests/unit/test_metrics_collector.py**
```python
# Unit tests for metrics
# Checklist:
# [ ] test_extract_tokens_anthropic
# [ ] test_extract_tokens_deepseek
# [ ] test_extract_tokens_modelstudio
# [ ] test_cost_calculation
# [ ] test_error_classification
# [ ] ~10-15 tests total
```

#### 26. **tests/integration/test_end_to_end.py**
```python
# End-to-end integration test
# Scenario: Request → Router → Scorer → Logging
# Checklist:
# [ ] test_full_routing_flow
# [ ] test_metrics_storage_and_query
# [ ] test_dashboard_api_integration
# [ ] test_alert_trigger_and_acknowledge
```

#### 27. **requirements.txt**
```
Flask==3.0.0
psycopg2-binary==2.9.9
pydantic==2.5.0
pydantic-settings==2.1.0
PyYAML==6.0.1
python-dotenv==1.0.0
requests==2.31.0
pytest==7.4.3
pytest-asyncio==0.21.1
redis==5.0.1  # optional
aioredis==2.0.1  # optional
```

#### 28. **setup.py**
```python
# Package setup
# Checklist:
# [ ] Package name: multi-agent-automation
# [ ] Version: 0.1.0
# [ ] Dependencies from requirements.txt
# [ ] Entry points (CLI?)
# [ ] Long description
```

#### 29. **.env.example**
```
# Environment template
# Checklist:
# [ ] DATABASE_URL=postgresql://...
# [ ] REDIS_URL=redis://...
# [ ] ANTHROPIC_API_KEY=...
# [ ] DEEPSEEK_API_KEY=...
# [ ] MODELSTUDIO_API_KEY=...
# [ ] TELEGRAM_BOT_TOKEN=...
# [ ] FLASK_ENV=development
# [ ] LOG_LEVEL=INFO
# [ ] BUDGET_LIMIT_USD=16.00
# [ ] ALERT_BUDGET_THRESHOLD_PERCENT=20
```

#### 30. **docs/SETUP.md**
```markdown
# Setup & Installation
# Checklist:
# [ ] Prerequisites (Python 3.10+, Docker, etc)
# [ ] Clone & install
# [ ] Environment setup
# [ ] Database migration
# [ ] Running the app
# [ ] Testing
# [ ] Docker setup
# [ ] Troubleshooting common issues
```

#### 31. **docs/API.md**
```markdown
# API Reference
# Checklist:
# [ ] Authentication
# [ ] All endpoints documented
# [ ] Request/response examples
# [ ] Error codes
# [ ] Rate limiting
# [ ] Pagination
```

#### 32. **README.md**
```markdown
# Multi-Agent Automation System
# Checklist:
# [ ] Project description
# [ ] Features overview
# [ ] Quick start
# [ ] Architecture diagram
# [ ] Folder structure
# [ ] Contributing
# [ ] License
```

---

## ⏱️ DEVELOPMENT WORKFLOW (PHASE 1)

### Week 1

**Day 1-2: Setup & Database**
- [ ] Create project folder structure
- [ ] Initialize git
- [ ] Set up Docker (TimescaleDB, Redis)
- [ ] Create docker-compose.yml
- [ ] Write init-db.sql
- [ ] Run `docker-compose up` and verify

**Day 3: Router Engine**
- [ ] Implement config/settings.py
- [ ] Write router/types.py
- [ ] Implement router/classifier.py with tests
- [ ] Implement router/scorer.py with tests
- [ ] Write config/routing_rules.yaml

**Day 4: Metrics Foundation**
- [ ] Implement metrics/types.py
- [ ] Implement metrics/collector.py
- [ ] Implement metrics/store.py (basic queries)
- [ ] Write integration test (collector → store)

**Day 5: Main Router**
- [ ] Implement router/router.py
- [ ] Integration test: request → classification → scoring → decision
- [ ] Handle edge cases
- [ ] Documentation

### Week 2

**Day 6-7: Alerts & Notifications**
- [ ] Implement metrics/alerts.py
- [ ] Implement metrics/notifier.py
- [ ] Add Telegram integration
- [ ] Test alert triggering

**Day 8-9: Dashboard Backend**
- [ ] Implement dashboard/app.py (Flask)
- [ ] Implement all routes (metrics, cost, alerts, budget)
- [ ] Implement services (metrics, cost, budget)
- [ ] Integration tests for API endpoints

**Day 10: Testing & Documentation**
- [ ] Complete all unit tests
- [ ] Complete integration tests
- [ ] Write setup.md, api.md, usage.md
- [ ] Write README.md
- [ ] Code review & cleanup

---

## 🧪 TESTING CHECKLIST (PHASE 1)

```
Unit Tests
══════════════════════════════════════════════════════════
[ ] Router:
    [ ] IntentClassifier.classify() - 10 tests
    [ ] AgentScorer.score_agent() - 8 tests
    [ ] AutoRouter.route() - 5 tests

[ ] Metrics:
    [ ] MetricsCollector.log_execution() - 6 tests
    [ ] MetricsStore.insert_metric() - 4 tests
    [ ] AlertEngine.check_metric() - 5 tests

[ ] Utilities:
    [ ] Cost calculation - 4 tests
    [ ] Token extraction - 6 tests
    [ ] Error classification - 3 tests

Total Unit Tests: ~50

Integration Tests
══════════════════════════════════════════════════════════
[ ] Router → Metrics flow - 3 tests
[ ] Database queries - 4 tests
[ ] Dashboard API - 5 tests
[ ] End-to-end scenarios - 2 tests

Total Integration Tests: ~14

Total: ~64 tests (target >80% code coverage)
```

---

## 🚀 GETTING STARTED (TODAY)

### Step 1: Create Project Structure
```bash
cd ~
mkdir -p multi-agent-automation
cd multi-agent-automation

mkdir -p config router metrics dashboard/routes dashboard/services dashboard/models dashboard/middleware docker scripts tests/{unit,integration,fixtures} docs data logs web/src/{pages,components,api,hooks,utils}

git init
```

### Step 2: Copy Core Files
- Copy routing_rules.yaml from MULTI_AGENT_AUTOMATION_PLAN.md
- Copy docker-compose.yml, init-db.sql
- Create .env.example

### Step 3: Start Implementation
- Day 1: settings.py + docker-compose.yml
- Day 2: types.py files + classifier.py
- Day 3: scorer.py + router.py
- Day 4: collector.py + store.py
- Day 5: alerts.py + dashboard app

### Step 4: Test & Deploy
- Unit tests for each module
- Integration tests
- Docker build & test
- Documentation

---

## 💾 FILE DEPENDENCIES (Import Order)

```
1. config/settings.py                     (no deps)
   ├── config/routing_rules.yaml          (external file)
   ├── config/agent_models.yaml           (external file)
   └── config/providers.yaml              (external file)

2. router/types.py                        (only stdlib)

3. router/classifier.py                   (uses types.py)

4. metrics/types.py                       (only stdlib)

5. metrics/store.py                       (uses types.py, settings.py)

6. router/scorer.py                       (uses types.py, metrics/store.py, settings.py)

7. router/router.py                       (uses all above + classifier + scorer)

8. metrics/collector.py                   (uses metrics/store.py, types.py, settings.py)

9. metrics/alerts.py                      (uses metrics/store.py, types.py, settings.py)

10. metrics/notifier.py                   (uses alerts.py, settings.py)

11. dashboard/models/schemas.py           (uses metrics/types.py)

12. dashboard/services/*.py               (uses metrics/store.py, schemas.py, settings.py)

13. dashboard/routes/*.py                 (uses services, schemas)

14. dashboard/app.py                      (imports routes)

15. tests/conftest.py                     (imports everything)

16. tests/unit/*.py                       (uses conftest fixtures)

17. tests/integration/*.py                (uses conftest fixtures)
```

---

## ✅ QUALITY GATES (Phase 1 Done When)

```
Code Quality
════════════════════════════════════════════════════════════
[ ] All code follows PEP8
[ ] Type hints on all functions
[ ] All functions have docstrings
[ ] No unused imports
[ ] No debug print() statements
[ ] Black formatter applied
[ ] mypy passes with --strict

Testing
════════════════════════════════════════════════════════════
[ ] >80% code coverage
[ ] All unit tests pass
[ ] All integration tests pass
[ ] No test warnings
[ ] Fixtures cleanup properly

Functionality
════════════════════════════════════════════════════════════
[ ] Router makes decisions with >0.7 confidence
[ ] Metrics collected for 100+ executions
[ ] Dashboard shows cost summary
[ ] Alerts triggered correctly
[ ] API endpoints return correct data

Documentation
════════════════════════════════════════════════════════════
[ ] README.md complete
[ ] SETUP.md with step-by-step instructions
[ ] API.md with all endpoints documented
[ ] ARCHITECTURE.md with diagrams
[ ] Code comments on complex logic
[ ] Type stubs for all modules

Deployment
════════════════════════════════════════════════════════════
[ ] Docker builds successfully
[ ] docker-compose up -d works
[ ] Database migrates without errors
[ ] App runs without manual setup
[ ] Health check passes
[ ] Logs are clean (no errors)
```

---

**This structure is ready to code against immediately.** Each file is scoped, dependencies are clear, and testing is comprehensive.

Next: mas Aris kicks off Phase 1 implementation (Week 1). Questions? Adjustments? 🧑‍🎄

