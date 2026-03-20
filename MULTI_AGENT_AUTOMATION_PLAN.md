# Multi-Agent Automation System — Comprehensive Project Plan

**Project Owner:** mas Aris  
**Created:** 2026-03-20  
**Version:** 1.0 (Final Spec)  
**Status:** Ready for Implementation

---

## 📋 EXECUTIVE SUMMARY

Build a **production-ready Multi-Agent Automation system** with three integrated components:

1. **Auto-Routing Engine** — Intelligent task classification & agent dispatch
2. **Performance Metrics Dashboard** — Real-time agent health, throughput, latency tracking
3. **Cost Monitoring & Budget Alerts** — Provider spend tracking, budget enforcement

This plan leverages the **existing 8-agent setup** (3 providers: Anthropic, DeepSeek, ModelStudio) and builds layered automation on top.

---

## 🎯 SECTION 1: CURRENT STATE ANALYSIS

### 1.1 Agent Setup (8 Agents, 3 Providers)

```
AGENTS DEPLOYMENT (Current as of 2026-03-20)

┌─────────────────────────────────────────────────────────────┐
│ ANTHROPIC (Tier 1 - Premium)                               │
├──────────────────────────────────────────────────────────────┤
│ • Agent1  (Orchestrator)   → claude-haiku-4-5              │
│ • Agent4  (Technical)      → claude-opus-4-6               │
│ • Agent5  (Lightweight)    → claude-haiku-4-5              │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│ DEEPSEEK (Tier 2 - Specialized)                            │
├──────────────────────────────────────────────────────────────┤
│ • Agent2  (Creative)       → deepseek-chat                 │
│ • Agent3  (Analytical)     → deepseek-reasoner             │
└──────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────┐
│ MODELSTUDIO/ALIBABA (Tier 3 - Cost-Optimized)              │
├──────────────────────────────────────────────────────────────┤
│ • Agent6  (General)        → qwen3.5-plus                  │
│ • Agent7  (Chat)           → qwen3-max                     │
│ • Agent8  (Specialized)    → qwen3-coder-next             │
└──────────────────────────────────────────────────────────────┘

BUDGET BASELINE (Monthly):
• Anthropic:   ~$8-12/month (premium tasks)
• DeepSeek:    ~$2-4/month (balanced quality/cost)
• ModelStudio: ~$0.50-1.50/month (cost-optimized)
• Total:       ~$11-17/month (sustainable)
```

### 1.2 Current Automation Status

**What exists:**
- ✅ Agent roles & personalities (SOUL.md defined per agent)
- ✅ Multi-agent spawning (via OpenClaw subagent feature)
- ✅ Basic cost scripts (check-all-balances.sh, provider APIs)
- ✅ Manual agent selection & coordination

**What's missing:**
- ❌ Automatic task → agent routing (rules engine)
- ❌ Unified performance metrics collection
- ❌ Real-time dashboard for agent health & cost
- ❌ Budget enforcement & alerts
- ❌ Agent performance analytics
- ❌ Historical tracking & optimization recommendations

### 1.3 Pain Points & Opportunities

| Pain Point | Impact | Solution in Plan |
|-----------|--------|-----------------|
| Manual agent selection | Slow dispatch, inconsistent routing | Auto-routing engine with rules |
| No visibility into agent perf | Can't optimize assignments | Metrics dashboard + analytics |
| Cost tracking is manual | Potential budget overrun | Automated monitoring & alerts |
| No performance history | Can't improve over time | Event logging + trend analysis |
| Cross-provider complexity | Hard to compare or rebalance | Unified metrics layer |

---

## 🎯 SECTION 2: AUTO-ROUTING ENGINE DESIGN

### 2.1 Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Task Input (User Request)                │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
        ┌──────────────────────────────────────┐
        │   ROUTER CLASSIFIER                   │
        │  (LLM-based intent detection)         │
        └──────────────────┬───────────────────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
              ▼            ▼            ▼
        ┌──────────┐ ┌──────────┐ ┌──────────┐
        │ RULES    │ │ CONTEXT  │ │ PERF     │
        │ ENGINE   │ │ ANALYZER │ │ SCORER   │
        │(domain)  │ │(metadata)│ │(metrics) │
        └────┬─────┘ └────┬─────┘ └────┬─────┘
             │            │            │
             └────────────┼────────────┘
                          │
                          ▼
        ┌──────────────────────────────────────┐
        │    AGENT SELECTOR & RANKER             │
        │  (Cost/Performance optimization)      │
        └──────────────────┬───────────────────┘
                           │
                ┌──────────┬┴──────────┐
                │          │          │
                ▼          ▼          ▼
           ┌────────┐ ┌────────┐ ┌────────┐
           │ Agent1 │ │ Agent2 │ │ AgentN │
           │(select)│ │(backup)│ │(pool)  │
           └────────┘ └────────┘ └────────┘
                │          │          │
                └──────────┼──────────┘
                           │
                           ▼
        ┌──────────────────────────────────────┐
        │    EXECUTION + MONITORING             │
        │ (log metrics, track cost)            │
        └──────────────────────────────────────┘
```

### 2.2 Router Rules Engine

**Task Classification (Intent Detection)**

```javascript
// types/router-types.ts
type TaskCategory = 
  | 'creative'       // Writing, copywriting, content creation
  | 'analytical'     // Data analysis, research, insights
  | 'technical'      // Coding, debugging, infrastructure
  | 'orchestration'  // Coordination, delegation, routing
  | 'chat'           // Conversational, support, engagement
  | 'general'        // Default/fallback

type TaskAttribute = {
  category: TaskCategory
  complexity: 'low' | 'medium' | 'high'
  costSensitive: boolean
  requiresReasoning: boolean
  timeConstraint: 'realtime' | 'normal' | 'background'
}

type RoutingDecision = {
  primaryAgent: string
  alternateAgents: string[]
  rationale: string
  estimatedCost: number
  confidenceScore: number
}
```

**Core Routing Rules**

```yaml
# config/routing-rules.yaml

rules:
  # CREATIVE TASKS
  - id: creative_content
    category: creative
    keywords: [write, create, copywriting, social, marketing, email, blog, headline, caption]
    primary_agent: agent2  # DeepSeek Creative
    fallback: [agent1, agent6]
    cost_class: medium
    complexity_threshold: medium
    
  - id: creative_marketing
    category: creative
    keywords: [campaign, brand, strategy, positioning, narrative, story]
    primary_agent: agent2
    fallback: [agent1, agent7]
    
  # ANALYTICAL TASKS
  - id: analytical_data
    category: analytical
    keywords: [analyze, research, data, report, insights, trends, forecast, statistics]
    primary_agent: agent3  # DeepSeek Reasoner
    fallback: [agent1, agent6]
    cost_class: medium
    complexity_threshold: high
    requires_reasoning: true
    
  - id: analytical_complex
    category: analytical
    keywords: [deep_analysis, forecasting, financial_analysis, research_paper]
    primary_agent: agent3
    fallback: [agent1]
    complexity_threshold: high
    requires_reasoning: true
    
  # TECHNICAL TASKS
  - id: technical_coding
    category: technical
    keywords: [code, fix, debug, implement, build, refactor, script, automation]
    primary_agent: agent4  # Claude Opus Technical
    fallback: [agent8, agent1]
    cost_class: high
    complexity_threshold: medium
    
  - id: technical_infrastructure
    category: technical
    keywords: [deploy, infrastructure, devops, server, container, pipeline, ci/cd]
    primary_agent: agent4
    fallback: [agent8, agent1]
    cost_class: high
    
  - id: technical_specialized
    category: technical
    keywords: [python, javascript, database, optimization, performance]
    primary_agent: agent8  # ModelStudio Coder
    fallback: [agent4, agent1]
    cost_class: low
    
  # ORCHESTRATION / ROUTING
  - id: orchestration_coordination
    category: orchestration
    keywords: [coordinate, route, dispatch, manage, orchestrate, delegate]
    primary_agent: agent1  # Orchestrator
    fallback: null  # Must succeed
    cost_class: low
    
  # CHAT / ENGAGEMENT
  - id: chat_conversational
    category: chat
    keywords: [chat, talk, discuss, question, answer, help, support, explain]
    primary_agent: agent7  # ModelStudio Chat
    fallback: [agent1, agent6]
    cost_class: low
    
  # GENERAL / FALLBACK
  - id: general_default
    category: general
    keywords: []  # Matches anything unclassified
    primary_agent: agent1  # Safe choice
    fallback: [agent6]
    cost_class: low

priority_overrides:
  # Cost-sensitive tasks (when budget low or explicit)
  - if: cost_sensitive == true
    boost_agent: agent6  # Prefer cheapest first
    boost_agent: agent7
    boost_agent: agent8
    
  # High-urgency tasks (realtime constraint)
  - if: time_constraint == 'realtime'
    boost_agent: agent1  # Fast routing
    boost_agent: agent5  # Fast haiku
    
  # Background tasks (low priority)
  - if: time_constraint == 'background'
    boost_agent: agent6  # Cost-optimized
    boost_agent: agent7
    boost_agent: agent8
```

### 2.3 Agent Scoring & Selection Algorithm

```python
# router/agent_scorer.py

class AgentScorer:
    """Rank agents by task fit + performance + cost"""
    
    def score_agent(self, agent_id: str, task: TaskAttribute) -> float:
        """
        Composite score = 
          (capability_match × 0.40) +
          (performance_score × 0.35) +
          (cost_efficiency × 0.25)
        """
        capability = self.match_capability(agent_id, task.category)
        performance = self.get_performance_score(agent_id)
        cost = self.get_cost_score(agent_id, task.cost_sensitive)
        
        return (capability * 0.40) + (performance * 0.35) + (cost * 0.25)
    
    def match_capability(self, agent_id: str, category: TaskCategory) -> float:
        """Check if agent is rated for this task type"""
        ratings = {
            'agent1': {'orchestration': 1.0, 'general': 0.9, ...},
            'agent2': {'creative': 1.0, 'marketing': 0.95, ...},
            'agent3': {'analytical': 1.0, 'research': 0.95, ...},
            'agent4': {'technical': 1.0, 'coding': 0.95, ...},
            # etc
        }
        return ratings.get(agent_id, {}).get(category, 0.5)
    
    def get_performance_score(self, agent_id: str) -> float:
        """
        From metrics: success_rate × response_time × quality_rating
        Recent performance weighted higher
        """
        metrics = self.metrics_store.get_agent_stats(agent_id, window='7d')
        
        success = metrics.success_rate  # 0-1
        latency = 1.0 - min(metrics.avg_latency / MAX_LATENCY, 1.0)  # lower is better
        quality = metrics.avg_rating / 5.0  # 0-1
        
        return (success × 0.5) + (latency × 0.3) + (quality × 0.2)
    
    def get_cost_score(self, agent_id: str, cost_sensitive: bool) -> float:
        """
        Cost-per-token or cost-per-request normalized
        If cost_sensitive: heavily prefer cheaper agents
        """
        cost_tier = self.get_agent_cost_tier(agent_id)  # 1=expensive, 3=cheap
        efficiency = cost_tier / 3.0  # Normalize to 0-1
        
        if cost_sensitive:
            efficiency = efficiency ** 1.5  # Amplify preference for cheap
        
        return efficiency

    def rank_agents(self, task: TaskAttribute, rules: RoutingRules) -> List[Tuple[str, float]]:
        """Return sorted list of [agent_id, score]"""
        
        # Get primary + fallbacks from rules
        candidates = rules.get_agents_for(task.category)
        
        # Score each candidate
        scores = [(agent, self.score_agent(agent, task)) 
                  for agent in candidates]
        
        # Sort by score (highest first)
        scores.sort(key=lambda x: x[1], reverse=True)
        
        return scores
```

### 2.4 Routing Workflow (Runtime)

```python
# router/router.py

class AutoRouter:
    """Main routing orchestrator"""
    
    def route(self, user_request: str) -> RoutingDecision:
        """
        1. Classify intent
        2. Extract task attributes
        3. Apply rules + scoring
        4. Select primary + fallback agents
        5. Log routing decision
        """
        
        # Step 1: Classify intent (using Agent1 or lightweight LLM)
        classification = self.classify_intent(user_request)
        
        # Step 2: Build task attribute
        task = TaskAttribute(
            category=classification.category,
            complexity=classification.complexity,
            costSensitive=self.check_budget_status(),
            requiresReasoning=classification.requires_reasoning,
            timeConstraint=self.extract_time_constraint(user_request)
        )
        
        # Step 3: Get rules for this category
        rules = self.rules_engine.get_rules(task.category)
        
        # Step 4: Rank agents
        ranked = self.agent_scorer.rank_agents(task, rules)
        
        # Step 5: Build decision
        decision = RoutingDecision(
            primaryAgent=ranked[0][0],
            alternateAgents=[a[0] for a in ranked[1:3]],
            rationale=f"Task: {task.category}, score: {ranked[0][1]:.2f}",
            estimatedCost=self.estimate_cost(ranked[0][0], user_request),
            confidenceScore=ranked[0][1]
        )
        
        # Step 6: Log
        self.metrics_store.log_routing(decision, user_request)
        
        return decision
    
    def classify_intent(self, text: str) -> Classification:
        """Classify task type from user request"""
        # Option A: Fast rule-based keywords
        # Option B: Quick LLM call to Agent1
        # For MVP: use keywords + heuristics
        pass
    
    def estimate_cost(self, agent_id: str, request: str) -> float:
        """Estimate token count → cost for this request"""
        # Rough estimate based on request length + agent model cost
        token_estimate = len(request.split()) * 1.3  # ~1.3x token per word
        cost_per_token = self.get_agent_cost_per_token(agent_id)
        return token_estimate * cost_per_token
```

---

## 🎯 SECTION 3: PERFORMANCE METRICS & TRACKING

### 3.1 Metrics Model

```typescript
// types/metrics-types.ts

interface AgentMetrics {
  agentId: string
  timestamp: ISO8601
  
  // Execution metrics
  taskId: string
  taskCategory: TaskCategory
  executionTimeMs: number
  tokensUsed: number
  costUSD: number
  
  // Quality metrics
  successStatus: 'success' | 'partial' | 'failed'
  userRating?: 1 | 2 | 3 | 4 | 5  // Optional post-execution rating
  errorType?: string
  
  // Context metrics
  contextWindowUsed: number
  contextWindowAvailable: number
  
  // Provider info
  provider: 'anthropic' | 'deepseek' | 'modelstudio'
  model: string
  
  // Routing info
  selectedByRouter: boolean
  routingConfidence?: number
  fallbackUsed?: boolean
}

interface AggregatedMetrics {
  agentId: string
  period: '1h' | '24h' | '7d' | '30d'
  
  // Throughput
  tasksCompleted: number
  tasksAttempted: number
  successRate: number  // 0-1
  
  // Latency
  avgExecutionTimeMs: number
  p50ExecutionTimeMs: number
  p95ExecutionTimeMs: number
  p99ExecutionTimeMs: number
  
  // Quality
  avgUserRating: number  // 1-5
  errorRate: number
  
  // Cost
  totalCostUSD: number
  avgCostPerTask: number
  costPerSuccessfulTask: number
  
  // Efficiency
  tokensPerTask: number
  costPerToken: number
  
  // Provider
  providerData: {
    apiCallsSuccessful: number
    apiCallsFailed: number
    rateLimitHits: number
  }
}

interface DashboardMetrics {
  timestamp: ISO8601
  period: '1h' | '24h' | '7d'
  
  // System-wide
  totalTasksProcessed: number
  totalCostUSD: number
  systemSuccessRate: number
  avgSystemLatencyMs: number
  
  // Per-agent summary
  agents: {
    [agentId: string]: AggregatedMetrics
  }
  
  // Per-provider summary
  providers: {
    anthropic: {
      tasksProcessed: number
      costUSD: number
      successRate: number
    },
    deepseek: { ... },
    modelstudio: { ... }
  }
  
  // Cost tracking
  budgetStatus: {
    totalBudgetUSD: number
    spentThisMonth: number
    remainingBudget: number
    projectedMonthEnd: number
    budgetHealthPercent: number  // 0-100, 100 = on track
  }
  
  // Alerts
  activeAlerts: Alert[]
}

interface Alert {
  id: string
  severity: 'info' | 'warning' | 'critical'
  type: 'budget_threshold' | 'agent_degradation' | 'cost_spike' | 'error_rate_high'
  message: string
  affectedAgents?: string[]
  createdAt: ISO8601
  acknowledged: boolean
}
```

### 3.2 Metrics Collection Architecture

```
┌─────────────────────────────────────────────────────────────┐
│               Agent Execution (OpenClaw)                    │
│  (Agent4 processes coding task in 2.3s, costs $0.012)       │
└───────────────────┬─────────────────────────────────────────┘
                    │ Emit metrics event
                    ▼
        ┌───────────────────────────────┐
        │  METRICS COLLECTOR            │
        │  (Background service)          │
        │  - Parse execution logs        │
        │  - Extract cost info           │
        │  - Normalize data              │
        └───────────────┬─────────────────┘
                        │
                        ▼
        ┌───────────────────────────────┐
        │  METRICS STORE                 │
        │  - TimescaleDB (time-series)   │
        │  - Fast queries for analytics  │
        │  - Retention: 90 days          │
        └───────────────┬─────────────────┘
                        │
        ┌───────────────┼───────────────┐
        ▼               ▼               ▼
   ┌────────┐    ┌──────────┐    ┌──────────┐
   │ALERTS  │    │ANALYTICS │    │DASHBOARD │
   │ENGINE  │    │ENGINE    │    │API       │
   └────────┘    └──────────┘    └──────────┘
        │               │               │
        └───────────────┼───────────────┘
                        ▼
        ┌───────────────────────────────┐
        │  REAL-TIME DASHBOARD (Web UI) │
        │  - Agent health               │
        │  - Cost trends                │
        │  - Performance leaderboard    │
        └───────────────────────────────┘
```

### 3.3 Metrics Collection Implementation

```python
# metrics/collector.py

class MetricsCollector:
    """Collects metrics from agent executions"""
    
    def __init__(self, metrics_store: MetricsStore, alert_engine: AlertEngine):
        self.store = metrics_store
        self.alerts = alert_engine
    
    def log_execution(self, execution_log: ExecutionLog) -> None:
        """
        Called after every agent task completes.
        Extracts metrics and stores them.
        """
        
        # Parse execution log
        agent_id = execution_log.agent_id
        task_id = execution_log.task_id
        duration_ms = execution_log.end_time - execution_log.start_time
        
        # Extract from provider response
        tokens = self.extract_tokens(execution_log)
        cost = self.calculate_cost(agent_id, tokens)
        
        # Determine success
        success = execution_log.exit_code == 0
        
        # Build metric
        metric = AgentMetrics(
            agentId=agent_id,
            timestamp=datetime.utcnow().isoformat(),
            taskId=task_id,
            taskCategory=execution_log.task_category,
            executionTimeMs=duration_ms,
            tokensUsed=tokens,
            costUSD=cost,
            successStatus='success' if success else 'failed',
            provider=self.get_agent_provider(agent_id),
            model=self.get_agent_model(agent_id),
            selectedByRouter=execution_log.selected_by_router,
            routingConfidence=execution_log.routing_confidence
        )
        
        # Store
        self.store.insert_metric(metric)
        
        # Check for alerts
        self.alerts.check_metric(metric)
    
    def extract_tokens(self, log: ExecutionLog) -> int:
        """Parse token usage from provider response"""
        # Different providers report differently
        if log.provider == 'anthropic':
            return log.response.usage.input_tokens + log.response.usage.output_tokens
        elif log.provider == 'deepseek':
            return log.response.usage.total_tokens
        elif log.provider == 'modelstudio':
            # ModelStudio doesn't always report tokens; estimate
            return len(log.response.text.split()) * 1.3
        return 0
    
    def calculate_cost(self, agent_id: str, tokens: int) -> float:
        """Convert tokens to cost in USD"""
        pricing = self.get_agent_pricing(agent_id)  # inputs/1K, outputs/1K
        # Rough estimate: split 50/50 input/output
        input_tokens = tokens * 0.5
        output_tokens = tokens * 0.5
        return (input_tokens / 1000 * pricing['input']) + \
               (output_tokens / 1000 * pricing['output'])

# metrics/store.py

class MetricsStore:
    """TimescaleDB-backed metrics storage"""
    
    def __init__(self, connection_string: str):
        self.conn = psycopg2.connect(connection_string)
        self.cursor = self.conn.cursor()
    
    def insert_metric(self, metric: AgentMetrics) -> None:
        """Store individual metric"""
        query = """
        INSERT INTO metrics.agent_executions 
        (agent_id, task_id, timestamp, execution_time_ms, tokens_used, 
         cost_usd, success_status, task_category, provider)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
        """
        self.cursor.execute(query, (
            metric.agentId, metric.taskId, metric.timestamp,
            metric.executionTimeMs, metric.tokensUsed, metric.costUSD,
            metric.successStatus, metric.taskCategory, metric.provider
        ))
        self.conn.commit()
    
    def get_agent_stats(self, agent_id: str, window: str = '7d') -> AggregatedMetrics:
        """Get aggregated metrics for agent over time period"""
        interval = {'1h': 'now() - interval 1 hour',
                   '24h': 'now() - interval 1 day',
                   '7d': 'now() - interval 7 days',
                   '30d': 'now() - interval 30 days'}[window]
        
        query = f"""
        SELECT 
            agent_id,
            COUNT(*) as tasks_completed,
            SUM(CASE WHEN success_status = 'success' THEN 1 ELSE 0 END)::float / COUNT(*) as success_rate,
            AVG(execution_time_ms) as avg_execution_time_ms,
            PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY execution_time_ms) as p50,
            PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY execution_time_ms) as p95,
            PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY execution_time_ms) as p99,
            SUM(cost_usd) as total_cost_usd,
            AVG(tokens_used) as avg_tokens_per_task
        FROM metrics.agent_executions
        WHERE agent_id = %s AND timestamp > {interval}
        GROUP BY agent_id
        """
        
        self.cursor.execute(query, (agent_id,))
        row = self.cursor.fetchone()
        
        return AggregatedMetrics(
            agentId=agent_id,
            period=window,
            tasksCompleted=row[1],
            successRate=row[2],
            avgExecutionTimeMs=row[3],
            p50ExecutionTimeMs=row[4],
            # ... etc
        )

# metrics/alerts.py

class AlertEngine:
    """Monitors metrics and triggers alerts"""
    
    def check_metric(self, metric: AgentMetrics) -> None:
        """Check single metric against alert thresholds"""
        
        # Alert: Cost spike
        avg_cost = self.get_avg_cost_for_agent(metric.agentId, window='7d')
        if metric.costUSD > avg_cost * 2:  # 2x normal = spike
            self.create_alert(
                severity='warning',
                type='cost_spike',
                message=f"Agent {metric.agentId} cost spike: ${metric.costUSD:.4f} (avg: ${avg_cost:.4f})",
                affected_agents=[metric.agentId]
            )
        
        # Alert: High error rate
        recent_success_rate = self.get_success_rate(metric.agentId, window='1h')
        if recent_success_rate < 0.8:
            self.create_alert(
                severity='critical',
                type='error_rate_high',
                message=f"Agent {metric.agentId} error rate high: {recent_success_rate:.1%}",
                affected_agents=[metric.agentId]
            )
        
        # Alert: Budget threshold
        monthly_spent = self.get_monthly_spend()
        remaining = self.budget_limit - monthly_spent
        if remaining < self.budget_limit * 0.1:  # < 10% remaining
            self.create_alert(
                severity='critical',
                type='budget_threshold',
                message=f"Budget warning: ${remaining:.2f} remaining of ${self.budget_limit:.2f}",
                affected_agents=None
            )
    
    def create_alert(self, severity: str, type: str, message: str, affected_agents: List[str]) -> None:
        """Store alert and notify"""
        alert = Alert(
            id=str(uuid.uuid4()),
            severity=severity,
            type=type,
            message=message,
            affectedAgents=affected_agents,
            createdAt=datetime.utcnow().isoformat(),
            acknowledged=False
        )
        
        # Store
        self.alert_store.save(alert)
        
        # Notify (Telegram, email, etc.)
        if severity in ['warning', 'critical']:
            self.notifier.send_alert(alert)
```

---

## 🎯 SECTION 4: COST MONITORING DASHBOARD

### 4.1 Dashboard Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   FRONTEND (React/Vue)                      │
│                                                              │
│  ┌──────────────────┐  ┌──────────────────┐                │
│  │ Cost Summary     │  │ Budget Health    │                │
│  │ Total: $8.42     │  │ 52% of $16/mo    │                │
│  └──────────────────┘  └──────────────────┘                │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Provider Breakdown (Pie Chart)                        │  │
│  │ Anthropic: 68% | DeepSeek: 21% | ModelStudio: 11%  │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Daily Cost Trend (Line Chart)                        │  │
│  │ [Graph showing 7-day spend pattern]                  │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  ┌──────────────────┐  ┌──────────────────┐                │
│  │ Top Agents by    │  │ Agent Performance│                │
│  │ Cost             │  │ Leaderboard      │                │
│  │ 1. Agent4: $3.21 │  │ 1. Agent1: 99%   │                │
│  │ 2. Agent1: $2.87 │  │ 2. Agent2: 97%   │                │
│  │ 3. Agent2: $1.54 │  │ 3. Agent3: 94%   │                │
│  └──────────────────┘  └──────────────────┘                │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ Alerts                                               │  │
│  │ ⚠️  Cost spike detected in Agent4 (2.3x normal)      │  │
│  │ ⚠️  Error rate high in Agent5 (22% failures)         │  │
│  │ ℹ️  ModelStudio API quota: 85% used                  │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ REST API calls
                            ▼
        ┌──────────────────────────────────┐
        │   BACKEND (Python Flask/FastAPI)  │
        │                                   │
        │  GET  /api/metrics/summary        │
        │  GET  /api/metrics/agents/{id}    │
        │  GET  /api/cost/breakdown         │
        │  GET  /api/cost/trend             │
        │  POST /api/alerts/{id}/acknowledge│
        │  GET  /api/budget/status          │
        └──────────────────┬────────────────┘
                           │
        ┌──────────────────┼──────────────────┐
        ▼                  ▼                  ▼
    ┌────────┐        ┌────────┐        ┌─────────┐
    │TimescaleDB│    │Redis Cache│    │Alert Store│
    │(Metrics)  │    │(Hot data)  │    │(Events)   │
    └────────┘        └────────┘        └─────────┘
```

### 4.2 Dashboard Views & Features

```typescript
// Web UI Routes

GET  /dashboard
     • Home page, cost summary, alerts
     
GET  /dashboard/cost
     • Cost breakdown by provider
     • Daily/weekly/monthly trends
     • Cost projections

GET  /dashboard/agents
     • Agent performance leaderboard
     • Per-agent cost/success/latency
     • Task distribution

GET  /dashboard/budget
     • Budget status
     • Monthly spend vs. limit
     • Alerts & thresholds

GET  /dashboard/alerts
     • Active alerts
     • Alert history
     • Acknowledge/dismiss

GET  /api/metrics/summary?period=24h
GET  /api/metrics/agents?period=7d
GET  /api/cost/breakdown?period=30d
POST /api/budget/set-limit (admin)
POST /api/alerts/{id}/acknowledge
```

### 4.3 Dashboard Features (MVP vs. Extended)

```
MVP (Phase 1)
═════════════
✅ Real-time cost display (total, by provider)
✅ Daily cost trend (7-day graph)
✅ Agent success rate leaderboard
✅ Active alerts (budget, errors, cost spikes)
✅ Manual alert acknowledgment
✅ Budget remaining display

Extended (Phase 2+)
═══════════════════
○ Cost projections (ML-based forecasting)
○ Agent efficiency scores (cost-adjusted)
○ Task category breakdown by cost
○ Custom alert rules UI
○ Cost attribution by task type
○ Provider failover recommendations
○ Agent rebalancing suggestions
○ Scheduled reports (daily/weekly)
○ Cost comparison (e.g., Agent4 vs Agent6 for coding)
○ Historical trend analysis
```

---

## 🎯 SECTION 5: IMPLEMENTATION PLAN

### 5.1 Project Structure

```
multi-agent-automation/
│
├── router/                           # Auto-routing engine
│   ├── __init__.py
│   ├── router.py                     # Main Router class
│   ├── classifier.py                 # Intent classification
│   ├── scorer.py                     # Agent scoring logic
│   └── rules_engine.py               # Rules evaluation
│
├── metrics/                          # Metrics collection & storage
│   ├── __init__.py
│   ├── collector.py                  # MetricsCollector
│   ├── store.py                      # MetricsStore (TimescaleDB)
│   ├── alerts.py                     # AlertEngine
│   └── notifier.py                   # Alert notifications
│
├── dashboard/                        # Web dashboard backend
│   ├── __init__.py
│   ├── app.py                        # Flask/FastAPI server
│   ├── routes/
│   │   ├── metrics.py                # GET /api/metrics/*
│   │   ├── cost.py                   # GET /api/cost/*
│   │   ├── alerts.py                 # GET/POST /api/alerts/*
│   │   └── budget.py                 # GET /api/budget/*
│   ├── services/
│   │   ├── metrics_service.py        # Business logic
│   │   ├── cost_service.py
│   │   ├── budget_service.py
│   │   └── alert_service.py
│   └── models/
│       └── schemas.py                # Pydantic schemas
│
├── config/                           # Configuration files
│   ├── routing_rules.yaml            # Auto-routing rules
│   ├── alert_rules.yaml              # Alert thresholds
│   ├── agent_models.yaml             # Agent → Model mapping
│   └── settings.py                   # Python config object
│
├── scripts/                          # Utilities
│   ├── migrate_db.py                 # Create TimescaleDB tables
│   ├── init_router.py                # Initialize router
│   └── check_health.py               # System health check
│
├── tests/                            # Unit & integration tests
│   ├── test_router.py
│   ├── test_scorer.py
│   ├── test_metrics.py
│   ├── test_dashboard.py
│   └── conftest.py
│
├── web/                              # Frontend (React/Vue)
│   ├── index.html
│   ├── src/
│   │   ├── App.tsx
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
│   │   │   └── MetricCard.tsx
│   │   └── api/
│   │       └── client.ts             # API client
│   └── package.json
│
├── docker/                           # Containerization
│   ├── Dockerfile                    # Main app
│   ├── docker-compose.yml            # Services (DB, Redis, API)
│   └── init-db.sql                   # Schema + seed
│
├── docs/                             # Documentation
│   ├── ARCHITECTURE.md               # System design
│   ├── API.md                        # API reference
│   ├── SETUP.md                      # Installation guide
│   └── USAGE.md                      # How to use
│
├── requirements.txt                  # Python dependencies
├── setup.py
└── README.md
```

### 5.2 Dependencies & Stack

```
BACKEND (Python)
════════════════
Framework:       Flask or FastAPI (async)
Database:        PostgreSQL + TimescaleDB extension
Caching:         Redis (optional, for hot metrics)
YAML:            PyYAML (for rules config)
HTTP Client:     requests or aiohttp
Validation:      Pydantic
Testing:         pytest, pytest-asyncio
Monitoring:      python-dotenv (env config)

WEB FRONTEND
════════════════
Framework:       React 18+ or Vue 3
Charts:          Chart.js or Recharts
UI Library:      Tailwind CSS or Material-UI
State Mgmt:      Zustand or Pinia
HTTP:            axios or fetch

INFRASTRUCTURE
════════════════
Container:       Docker + docker-compose
Time-Series DB:  TimescaleDB (PostgreSQL ext.)
Cache:           Redis (optional)
Deployment:      systemd service + cron for backups

OPTIONAL (Phase 2)
════════════════════
ML Forecasting:  scikit-learn or statsmodels
Notifications:   Telegram Bot API, sendgrid (email)
Monitoring:      Prometheus + Grafana
```

### 5.3 Implementation Phases

```
PHASE 1: Foundation (Weeks 1-2)
═════════════════════════════════════════════════════════════════
Goals:
  • Establish metrics collection infrastructure
  • Implement basic auto-router with rules engine
  • Deploy TimescaleDB for metrics storage
  • Build minimal dashboard (cost summary + alerts)

Tasks:
  1.1  Set up PostgreSQL + TimescaleDB
       - Create metrics schema (agent_executions table, etc.)
       - Index on agent_id, timestamp for fast queries
       - Retention policy (90 days)
  
  1.2  Implement MetricsCollector
       - Hook into OpenClaw execution logs
       - Parse tokens/cost from provider responses
       - Store metrics in TimescaleDB
  
  1.3  Build AutoRouter + RulesEngine
       - Load routing_rules.yaml
       - Implement intent classifier (keyword-based MVP)
       - Implement agent scorer
       - Test with 20+ example requests
  
  1.4  Dashboard MVP (Flask app)
       - GET /api/metrics/summary (cost total, by provider)
       - GET /api/cost/breakdown
       - GET /api/alerts
       - Simple HTML dashboard (cost card, alerts list)
  
  1.5  Testing & documentation
       - Unit tests for router, scorer, collector
       - API endpoint tests
       - Setup guide

Deliverables:
  ✓ metrics/ folder (collector + store)
  ✓ router/ folder (router + rules engine)
  ✓ dashboard/ folder (Flask backend)
  ✓ config/routing_rules.yaml
  ✓ docker/docker-compose.yml (with TimescaleDB)
  ✓ Integration tests passing

Timeline: 2 weeks
Effort:   ~80 hours


PHASE 2: Enhancement (Weeks 3-4)
═════════════════════════════════════════════════════════════════
Goals:
  • Upgrade dashboard to React/Vue UI
  • Add real-time WebSocket updates
  • Implement alert notifications (Telegram)
  • Improve router with LLM-based classification

Tasks:
  2.1  React Dashboard frontend
       - Build components (CostChart, Leaderboard, Alerts)
       - Connect to backend API
       - Real-time updates via WebSocket
       - Responsive mobile design
  
  2.2  AlertEngine + Notifications
       - Implement AlertEngine.check_metric()
       - Add alert thresholds (budget, error rate, cost spike)
       - Telegram bot integration
       - Email notifications (optional)
  
  2.3  Enhanced Router
       - LLM-based intent classifier (Agent1 short calls)
       - Cache classification results
       - Add user feedback loop (rate routing quality)
  
  2.4  Agent performance features
       - Agent leaderboard (success rate, latency, cost)
       - Per-task-category efficiency rankings
       - Alert per agent (degradation detection)
  
  2.5  Admin features
       - Budget limit setting
       - Alert threshold configuration
       - Manual agent rebalancing

Deliverables:
  ✓ web/ folder (React app)
  ✓ AlertEngine implementation
  ✓ Telegram bot integration
  ✓ Enhanced router with LLM classification
  ✓ Agent leaderboard data
  ✓ Admin panel

Timeline: 2 weeks
Effort:   ~70 hours


PHASE 3: Optimization & Scaling (Weeks 5-6)
═════════════════════════════════════════════════════════════════
Goals:
  • Cost forecasting & ML optimization
  • Advanced routing (cost-benefit analysis)
  • Scheduled reports & recommendations
  • Production hardening

Tasks:
  3.1  ML forecasting (optional)
       - Predict daily/monthly costs 7-30 days ahead
       - Seasonal trend detection
       - Anomaly detection for cost spikes
  
  3.2  Advanced routing
       - Cost-aware routing: "use cheaper agent if quality OK"
       - Failover strategy: fallback handling + retry logic
       - Dynamic rule updates (A/B test agent assignments)
  
  3.3  Recommendations engine
       - Suggest better agent for task type (cost vs. perf)
       - Rebalancing recommendations (when to scale agents)
       - Cost optimization tips
  
  3.4  Production hardening
       - Rate limiting on API endpoints
       - Auth for dashboard (password/API key)
       - Backup & disaster recovery
       - Log rotation & cleanup
  
  3.5  Scheduled reporting
       - Daily cost report (email/Telegram)
       - Weekly performance summary
       - Monthly optimization recommendations

Deliverables:
  ✓ ML forecasting models
  ✓ Cost recommendation engine
  ✓ Scheduled reporters
  ✓ Production-ready deployment
  ✓ Admin auth & security
  ✓ Comprehensive docs

Timeline: 2 weeks
Effort:   ~60 hours


TOTAL PROJECT TIMELINE: ~6 weeks, ~210 hours
```

### 5.4 Detailed Phase 1 Tasks (Expansion)

#### Task 1.1: Database Setup

```bash
# Docker setup (docker/docker-compose.yml)

version: '3.9'
services:
  timescaledb:
    image: timescale/timescaledb-docker-ha:latest-pg14
    environment:
      POSTGRES_USER: metrics_user
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: metrics_db
    volumes:
      - ./docker/init-db.sql:/docker-entrypoint-initdb.d/01-init.sql
      - timescaledb_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "metrics_user"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

  backend:
    build:
      context: .
      dockerfile: docker/Dockerfile
    environment:
      DATABASE_URL: postgresql://metrics_user:${DB_PASSWORD}@timescaledb:5432/metrics_db
      REDIS_URL: redis://redis:6379
      FLASK_ENV: production
    ports:
      - "5000:5000"
    depends_on:
      timescaledb:
        condition: service_healthy
    volumes:
      - ./:/app

volumes:
  timescaledb_data:
```

```sql
-- docker/init-db.sql
-- Create TimescaleDB hypertable for metrics

CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;

CREATE TABLE metrics.agent_executions (
    id BIGSERIAL,
    agent_id VARCHAR(50) NOT NULL,
    task_id VARCHAR(100) NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL,
    execution_time_ms INT NOT NULL,
    tokens_used INT,
    cost_usd NUMERIC(10, 6),
    success_status VARCHAR(20) NOT NULL,
    task_category VARCHAR(50),
    provider VARCHAR(50),
    model VARCHAR(100),
    selected_by_router BOOLEAN DEFAULT FALSE,
    routing_confidence NUMERIC(3, 2),
    error_type VARCHAR(200),
    user_rating INT,
    context_window_used INT,
    context_window_available INT,
    PRIMARY KEY (id, timestamp)
);

-- Convert to hypertable (auto-partitioning by time)
SELECT create_hypertable('metrics.agent_executions', 'timestamp', 
       if_not_exists => TRUE);

-- Indexes for fast queries
CREATE INDEX ON metrics.agent_executions (agent_id, timestamp DESC);
CREATE INDEX ON metrics.agent_executions (provider, timestamp DESC);
CREATE INDEX ON metrics.agent_executions (task_category, timestamp DESC);
CREATE INDEX ON metrics.agent_executions (success_status, timestamp DESC);

-- Retention policy: keep 90 days
SELECT add_retention_policy('metrics.agent_executions', INTERVAL '90 days', 
       if_not_exists => TRUE);

-- Alerts table
CREATE TABLE alerts.active_alerts (
    id UUID PRIMARY KEY,
    severity VARCHAR(20) NOT NULL,
    type VARCHAR(50) NOT NULL,
    message TEXT,
    affected_agents TEXT[], -- Array of agent IDs
    created_at TIMESTAMPTZ NOT NULL,
    acknowledged BOOLEAN DEFAULT FALSE,
    acknowledged_at TIMESTAMPTZ
);

CREATE INDEX ON alerts.active_alerts (created_at DESC);
CREATE INDEX ON alerts.active_alerts (severity);

-- Budget tracking
CREATE TABLE budget.monthly_spend (
    month DATE PRIMARY KEY,
    provider VARCHAR(50),
    amount_usd NUMERIC(10, 2),
    PRIMARY KEY (month, provider)
);

CREATE INDEX ON budget.monthly_spend (month DESC);
```

#### Task 1.2: MetricsCollector Implementation

```python
# metrics/collector.py

import logging
from datetime import datetime
from typing import Dict, Any
from dataclasses import dataclass, asdict
from metrics.store import MetricsStore
from metrics.alerts import AlertEngine
from config.settings import AGENT_PRICING

logger = logging.getLogger(__name__)

@dataclass
class ExecutionLog:
    """Represents a single agent execution"""
    agent_id: str
    task_id: str
    task_category: str
    start_time: float  # Unix timestamp
    end_time: float
    provider: str
    model: str
    provider_response: Dict[str, Any]  # Raw API response
    exit_code: int
    selected_by_router: bool = False
    routing_confidence: float = None
    error_message: str = None

class MetricsCollector:
    """Collects and stores agent execution metrics"""
    
    def __init__(self, metrics_store: MetricsStore, alert_engine: AlertEngine):
        self.store = metrics_store
        self.alerts = alert_engine
    
    def log_execution(self, exec_log: ExecutionLog) -> None:
        """
        Process a completed agent execution.
        Extract metrics, calculate cost, check for alerts.
        """
        try:
            # Calculate metrics
            duration_ms = int((exec_log.end_time - exec_log.start_time) * 1000)
            tokens = self._extract_tokens(exec_log)
            cost_usd = self._calculate_cost(exec_log.agent_id, tokens)
            success = exec_log.exit_code == 0
            
            # Prepare metric record
            metric = {
                'agent_id': exec_log.agent_id,
                'task_id': exec_log.task_id,
                'timestamp': datetime.utcnow().isoformat() + 'Z',
                'execution_time_ms': duration_ms,
                'tokens_used': tokens,
                'cost_usd': cost_usd,
                'success_status': 'success' if success else 'failed',
                'task_category': exec_log.task_category,
                'provider': exec_log.provider,
                'model': exec_log.model,
                'selected_by_router': exec_log.selected_by_router,
                'routing_confidence': exec_log.routing_confidence,
                'error_type': self._classify_error(exec_log.error_message) if exec_log.error_message else None,
            }
            
            # Store
            self.store.insert_metric(metric)
            logger.info(f"Logged execution: {exec_log.agent_id} ({exec_log.task_id}) - ${cost_usd:.4f}")
            
            # Check for alerts
            self.alerts.check_metric(metric)
        
        except Exception as e:
            logger.error(f"Error logging execution {exec_log.task_id}: {e}", exc_info=True)
    
    def _extract_tokens(self, exec_log: ExecutionLog) -> int:
        """Parse token usage from provider response"""
        resp = exec_log.provider_response
        
        if exec_log.provider == 'anthropic':
            if 'usage' in resp:
                return resp['usage'].get('input_tokens', 0) + resp['usage'].get('output_tokens', 0)
        
        elif exec_log.provider == 'deepseek':
            if 'usage' in resp:
                return resp['usage'].get('total_tokens', 0)
        
        elif exec_log.provider == 'modelstudio':
            # ModelStudio often doesn't report; estimate from content
            if 'choices' in resp and resp['choices']:
                text = resp['choices'][0].get('message', {}).get('content', '')
                # Rough estimate: 1.3 tokens per word
                return int(len(text.split()) * 1.3)
        
        return 0
    
    def _calculate_cost(self, agent_id: str, tokens: int) -> float:
        """Convert tokens to USD cost"""
        if tokens == 0:
            return 0.0
        
        # Get pricing for this agent's model
        pricing = AGENT_PRICING.get(agent_id)
        if not pricing:
            logger.warning(f"No pricing found for agent {agent_id}")
            return 0.0
        
        input_rate = pricing.get('input_per_1k_tokens', 0)
        output_rate = pricing.get('output_per_1k_tokens', 0)
        
        # Rough estimate: 50/50 input/output split
        cost = (tokens * 0.5 / 1000 * input_rate) + (tokens * 0.5 / 1000 * output_rate)
        return round(cost, 6)
    
    def _classify_error(self, error_msg: str) -> str:
        """Categorize error for analysis"""
        error_lower = error_msg.lower()
        
        if 'rate' in error_lower or '429' in error_lower:
            return 'rate_limit'
        elif 'timeout' in error_lower or 'timeout' in error_lower:
            return 'timeout'
        elif 'auth' in error_lower or 'unauthorized' in error_lower:
            return 'auth_failed'
        elif 'context' in error_lower or 'overflow' in error_lower:
            return 'context_overflow'
        else:
            return 'other'

# Usage in agent execution wrapper:

from metrics.collector import MetricsCollector

def execute_agent_task(agent_id: str, task_request: str, task_category: str) -> str:
    """Execute agent and collect metrics"""
    
    start_time = time.time()
    collector = MetricsCollector(metrics_store, alert_engine)
    
    try:
        # Execute agent
        response = call_agent_api(agent_id, task_request)
        provider = get_agent_provider(agent_id)
        model = get_agent_model(agent_id)
        
        # Log successful execution
        exec_log = ExecutionLog(
            agent_id=agent_id,
            task_id=generate_task_id(),
            task_category=task_category,
            start_time=start_time,
            end_time=time.time(),
            provider=provider,
            model=model,
            provider_response=response,
            exit_code=0,
            selected_by_router=True,  # Set based on router decision
        )
        
        collector.log_execution(exec_log)
        return response['text']
    
    except Exception as e:
        # Log failed execution
        exec_log = ExecutionLog(
            agent_id=agent_id,
            task_id=generate_task_id(),
            task_category=task_category,
            start_time=start_time,
            end_time=time.time(),
            provider=provider,
            model=model,
            provider_response={},
            exit_code=1,
            error_message=str(e),
        )
        
        collector.log_execution(exec_log)
        raise
```

#### Task 1.3: Auto-Router Implementation

```python
# router/router.py

import logging
import yaml
from typing import List, Tuple, Dict
from dataclasses import dataclass
from router.classifier import IntentClassifier
from router.scorer import AgentScorer
from config.settings import AGENT_MODELS, AGENT_PROVIDERS
from metrics.store import MetricsStore

logger = logging.getLogger(__name__)

@dataclass
class TaskAttribute:
    category: str  # creative, analytical, technical, orchestration, chat, general
    complexity: str  # low, medium, high
    cost_sensitive: bool
    requires_reasoning: bool
    time_constraint: str  # realtime, normal, background

@dataclass
class RoutingDecision:
    primary_agent: str
    alternate_agents: List[str]
    rationale: str
    estimated_cost: float
    confidence_score: float

class AutoRouter:
    """Main routing orchestrator"""
    
    def __init__(self, 
                 rules_file: str = 'config/routing_rules.yaml',
                 metrics_store: MetricsStore = None):
        
        self.classifier = IntentClassifier()
        self.scorer = AgentScorer(metrics_store)
        self.metrics_store = metrics_store
        
        # Load routing rules
        with open(rules_file, 'r') as f:
            self.rules_config = yaml.safe_load(f)
        
        logger.info("AutoRouter initialized")
    
    def route(self, user_request: str, budget_status: Dict = None) -> RoutingDecision:
        """
        Main routing method:
        1. Classify intent
        2. Build task attributes
        3. Apply rules + scoring
        4. Select best agent
        5. Log decision
        """
        
        # Step 1: Classify intent
        classification = self.classifier.classify(user_request)
        logger.debug(f"Classification: {classification}")
        
        # Step 2: Build task attributes
        task = TaskAttribute(
            category=classification['category'],
            complexity=classification['complexity'],
            cost_sensitive=(budget_status or {}).get('remaining_percent', 100) < 30,
            requires_reasoning=classification.get('requires_reasoning', False),
            time_constraint=self._extract_time_constraint(user_request)
        )
        
        logger.debug(f"Task attributes: category={task.category}, complexity={task.complexity}, cost_sensitive={task.cost_sensitive}")
        
        # Step 3: Get rules for this category
        rules = self._get_rules_for_category(task.category)
        candidates = rules['agents']  # e.g., ['agent2', 'agent1', 'agent6']
        
        # Step 4: Score candidates
        scored = []
        for agent_id in candidates:
            score = self.scorer.score_agent(agent_id, task)
            scored.append((agent_id, score))
        
        # Sort by score (highest first)
        scored.sort(key=lambda x: x[1], reverse=True)
        
        primary = scored[0][0]
        alternates = [a[0] for a in scored[1:3]]
        
        # Build decision
        decision = RoutingDecision(
            primary_agent=primary,
            alternate_agents=alternates,
            rationale=f"Task: {task.category} ({task.complexity}), top score: {scored[0][1]:.2f}",
            estimated_cost=self._estimate_cost(primary, user_request),
            confidence_score=scored[0][1]
        )
        
        # Step 5: Log
        if self.metrics_store:
            self.metrics_store.log_routing_decision(decision, user_request)
        
        logger.info(f"Routing decision: {primary} (conf: {decision.confidence_score:.2f})")
        return decision
    
    def _get_rules_for_category(self, category: str) -> Dict:
        """Get routing rules for task category"""
        for rule in self.rules_config.get('rules', []):
            if rule['category'] == category:
                return rule
        
        # Fallback to general/default rule
        for rule in self.rules_config.get('rules', []):
            if rule.get('id') == 'general_default':
                return rule
        
        # Ultimate fallback
        return {'agents': ['agent1'], 'cost_class': 'low'}
    
    def _extract_time_constraint(self, text: str) -> str:
        """Detect urgency from request"""
        urgent_words = ['asap', 'urgent', 'immediately', 'now', 'quick', 'fast']
        slow_words = ['background', 'batch', 'scheduled', 'later', 'when available']
        
        text_lower = text.lower()
        
        if any(w in text_lower for w in urgent_words):
            return 'realtime'
        elif any(w in text_lower for w in slow_words):
            return 'background'
        else:
            return 'normal'
    
    def _estimate_cost(self, agent_id: str, request: str) -> float:
        """Rough cost estimate"""
        # Estimate tokens from request length
        token_estimate = len(request.split()) * 1.3  # ~1.3 tokens per word
        
        # Get pricing
        provider = AGENT_PROVIDERS[agent_id]
        pricing = AGENT_PRICING[agent_id]
        
        input_rate = pricing['input_per_1k_tokens']
        output_rate = pricing['output_per_1k_tokens']
        
        # Assume 50/50 input/output, output ~50% of input length
        total_tokens = token_estimate * 1.5
        cost = (total_tokens / 1000) * ((input_rate + output_rate) / 2)
        
        return round(cost, 4)

# router/classifier.py

class IntentClassifier:
    """Classify user request into task category"""
    
    KEYWORDS = {
        'creative': [
            'write', 'create', 'copywriting', 'social', 'marketing', 'email',
            'blog', 'headline', 'caption', 'campaign', 'brand', 'story'
        ],
        'analytical': [
            'analyze', 'research', 'data', 'report', 'insights', 'trends',
            'forecast', 'statistics', 'financial'
        ],
        'technical': [
            'code', 'fix', 'debug', 'implement', 'build', 'refactor',
            'deploy', 'infrastructure', 'devops', 'python', 'javascript'
        ],
        'chat': [
            'chat', 'talk', 'discuss', 'question', 'answer', 'help', 'support', 'explain'
        ],
        'orchestration': [
            'coordinate', 'route', 'dispatch', 'manage', 'orchestrate', 'delegate'
        ]
    }
    
    def classify(self, text: str) -> Dict[str, any]:
        """Classify request into category"""
        text_lower = text.lower()
        
        # Count keyword matches per category
        matches = {}
        for category, keywords in self.KEYWORDS.items():
            count = sum(1 for kw in keywords if kw in text_lower)
            if count > 0:
                matches[category] = count
        
        # Get top category
        if matches:
            category = max(matches.keys(), key=lambda k: matches[k])
        else:
            category = 'general'
        
        # Determine complexity
        complexity = self._estimate_complexity(text)
        requires_reasoning = 'analyze' in text_lower or 'research' in text_lower
        
        return {
            'category': category,
            'complexity': complexity,
            'requires_reasoning': requires_reasoning,
            'confidence': matches.get(category, 0) / max(len(text_lower.split()), 1)
        }
    
    def _estimate_complexity(self, text: str) -> str:
        """Estimate task complexity"""
        length = len(text.split())
        
        if length > 300:
            return 'high'
        elif length > 100:
            return 'medium'
        else:
            return 'low'

# router/scorer.py

class AgentScorer:
    """Score agents based on task fit and performance"""
    
    CAPABILITY_RATINGS = {
        'agent1': {'orchestration': 1.0, 'general': 0.9, 'chat': 0.8},
        'agent2': {'creative': 1.0, 'marketing': 0.95, 'chat': 0.8},
        'agent3': {'analytical': 1.0, 'research': 0.95, 'general': 0.7},
        'agent4': {'technical': 1.0, 'coding': 0.95, 'general': 0.8},
        'agent5': {'general': 0.8, 'chat': 0.7, 'orchestration': 0.6},
        'agent6': {'general': 0.9, 'analytical': 0.7, 'creative': 0.7},
        'agent7': {'chat': 0.95, 'general': 0.85, 'creative': 0.7},
        'agent8': {'technical': 0.95, 'coding': 1.0, 'general': 0.75},
    }
    
    COST_TIERS = {  # 1 = expensive, 3 = cheap
        'agent1': 2,  # Haiku (moderate)
        'agent2': 2,  # DeepSeek (moderate)
        'agent3': 2,  # DeepSeek (moderate)
        'agent4': 1,  # Opus (expensive)
        'agent5': 2,  # Haiku (moderate)
        'agent6': 3,  # ModelStudio (cheap)
        'agent7': 3,  # ModelStudio (cheap)
        'agent8': 3,  # ModelStudio (cheap)
    }
    
    def __init__(self, metrics_store = None):
        self.metrics_store = metrics_store
    
    def score_agent(self, agent_id: str, task: TaskAttribute) -> float:
        """
        Composite score (0-1):
        - 40% capability match
        - 35% recent performance
        - 25% cost efficiency
        """
        
        capability = self._score_capability(agent_id, task.category)
        performance = self._score_performance(agent_id)
        cost = self._score_cost(agent_id, task.cost_sensitive)
        
        composite = (capability * 0.40) + (performance * 0.35) + (cost * 0.25)
        return min(composite, 1.0)
    
    def _score_capability(self, agent_id: str, category: str) -> float:
        """0-1: how well agent suited for task category"""
        ratings = self.CAPABILITY_RATINGS.get(agent_id, {})
        return ratings.get(category, 0.5)
    
    def _score_performance(self, agent_id: str) -> float:
        """0-1: recent success rate + latency"""
        if not self.metrics_store:
            return 0.7  # Neutral default
        
        stats = self.metrics_store.get_agent_stats(agent_id, window='7d')
        
        if not stats:
            return 0.7
        
        # success_rate (0-1) weighted 70%
        # latency bonus (fast = higher) weighted 30%
        success = stats['success_rate']
        latency = max(0, 1.0 - (stats['avg_latency_ms'] / 5000))  # 5s = baseline
        
        return (success * 0.7) + (latency * 0.3)
    
    def _score_cost(self, agent_id: str, cost_sensitive: bool) -> float:
        """0-1: cost efficiency (higher tier = lower score)"""
        tier = self.COST_TIERS.get(agent_id, 2)
        efficiency = tier / 3.0  # Normalize to 0-1
        
        if cost_sensitive:
            efficiency = efficiency ** 1.5  # Amplify preference for cheap agents
        
        return efficiency
```

---

## 🎯 SECTION 6: QUICK START & NEXT STEPS

### 6.1 Immediate Action Items (This Week)

- [ ] **1. Create project folder**
  ```bash
  mkdir -p ~/multi-agent-automation
  cd ~/multi-agent-automation
  git init
  ```

- [ ] **2. Set up Docker environment**
  - Copy docker-compose.yml from Phase 1.1
  - Copy init-db.sql
  - Run: `docker-compose up -d`

- [ ] **3. Implement metrics/collector.py**
  - Code from Phase 1.2 above
  - Write unit tests

- [ ] **4. Implement router/ folder**
  - Create router.py, classifier.py, scorer.py
  - Load routing_rules.yaml
  - Test with 20+ mock requests

- [ ] **5. Build Flask API skeleton**
  - GET /api/metrics/summary
  - GET /api/cost/breakdown
  - GET /api/alerts

- [ ] **6. Document everything**
  - README.md (project overview)
  - SETUP.md (installation)
  - API.md (endpoint reference)

### 6.2 Testing Strategy

```python
# tests/test_router.py

def test_router_creative_task():
    """Routing creative task should select agent2"""
    request = "Write a compelling email for product launch"
    decision = router.route(request)
    assert decision.primary_agent in ['agent2', 'agent1']
    assert decision.confidence_score > 0.6

def test_router_technical_task():
    """Routing technical task should prefer agent4 or agent8"""
    request = "Fix the Python script that processes CSV files"
    decision = router.route(request)
    assert decision.primary_agent in ['agent4', 'agent8', 'agent1']

def test_router_cost_sensitive():
    """When cost_sensitive, prefer cheaper agents"""
    request = "Analyze sales data"
    decision = router.route(request, budget_status={'remaining_percent': 15})
    # Should prefer cheaper alternatives
    assert decision.primary_agent != 'agent4'  # Most expensive

def test_metrics_collector_cost_calculation():
    """Cost calculation should be accurate"""
    exec_log = ExecutionLog(...)
    collector.log_execution(exec_log)
    # Verify cost was calculated correctly
```

### 6.3 Success Criteria

**Phase 1 Complete When:**
- ✅ MetricsCollector successfully logs 100+ executions
- ✅ AutoRouter makes routing decisions with >0.7 confidence
- ✅ Dashboard displays real-time cost summary
- ✅ All tests passing (router, scorer, collector, API)
- ✅ Documentation complete

**Phase 2 Complete When:**
- ✅ React dashboard deployed with all views
- ✅ Telegram alerts triggered correctly
- ✅ Agent leaderboard shows performance rankings
- ✅ Real-time WebSocket updates working

**Phase 3 Complete When:**
- ✅ Cost forecasting active & accurate
- ✅ Recommendations engine deployed
- ✅ Production hardening complete
- ✅ Scheduled reports running

---

## 📊 APPENDIX: Configuration Examples

### routing_rules.yaml (Full)

```yaml
# config/routing_rules.yaml

version: 1.0
description: "Auto-routing rules for 8-agent system"

rules:
  - id: creative_content
    category: creative
    keywords: [write, create, copywriting, social, marketing, email, blog, headline, caption]
    primary_agent: agent2
    fallback: [agent1, agent6]
    cost_class: medium
    min_confidence: 0.5
    
  - id: creative_campaigns
    category: creative
    keywords: [campaign, brand, strategy, positioning, narrative, story, branding]
    primary_agent: agent2
    fallback: [agent1, agent7]
    cost_class: medium
    
  - id: analytical_data
    category: analytical
    keywords: [analyze, research, data, report, insights, trends, forecast]
    primary_agent: agent3
    fallback: [agent1, agent6]
    cost_class: medium
    requires_reasoning: true
    
  - id: analytical_complex
    category: analytical
    keywords: [deep_analysis, forecasting, financial_analysis, research_paper, statistical]
    primary_agent: agent3
    fallback: [agent1]
    cost_class: medium
    complexity_min: high
    
  - id: technical_coding
    category: technical
    keywords: [code, fix, debug, implement, build, refactor, script]
    primary_agent: agent4
    fallback: [agent8, agent1]
    cost_class: high
    
  - id: technical_infrastructure
    category: technical
    keywords: [deploy, infrastructure, devops, server, container, pipeline, ci/cd, k8s]
    primary_agent: agent4
    fallback: [agent8, agent1]
    cost_class: high
    
  - id: technical_specialized
    category: technical
    keywords: [python, javascript, database, optimization, performance, caching, query]
    primary_agent: agent8
    fallback: [agent4, agent1]
    cost_class: low
    
  - id: orchestration
    category: orchestration
    keywords: [coordinate, route, dispatch, manage, orchestrate, delegate, spawn]
    primary_agent: agent1
    fallback: null
    cost_class: low
    
  - id: chat_support
    category: chat
    keywords: [chat, talk, discuss, question, answer, help, support, explain]
    primary_agent: agent7
    fallback: [agent1, agent6]
    cost_class: low
    
  - id: general_default
    category: general
    keywords: []
    primary_agent: agent1
    fallback: [agent6]
    cost_class: low

# Priority overrides
priority_overrides:
  cost_sensitive:
    boost_preference: [agent6, agent7, agent8, agent5]
    reduce_preference: [agent4]
    threshold: 20  # % of budget remaining
  
  realtime:
    boost_preference: [agent1, agent5]  # Fast models
    reduce_preference: [agent3]  # Slowest (reasoning)
  
  background:
    boost_preference: [agent6, agent7, agent8]  # Cheap
    reduce_preference: [agent4]  # Expensive

# Budget tiers (for cost-aware routing)
cost_tiers:
  tier1_expensive:
    agents: [agent4]
    avg_cost_per_task: 0.025
    use_when: "high_complexity OR user_premium"
  
  tier2_moderate:
    agents: [agent1, agent2, agent3, agent5]
    avg_cost_per_task: 0.008
    use_when: "normal"
  
  tier3_cheap:
    agents: [agent6, agent7, agent8]
    avg_cost_per_task: 0.001
    use_when: "cost_sensitive OR background_task"
```

---

## 📄 FINAL SUMMARY

This comprehensive plan provides:

✅ **Current State Analysis** — 8 agents, 3 providers, baseline architecture  
✅ **Auto-Routing Design** — Rules engine, classifier, scorer, workflow  
✅ **Metrics Framework** — Collection, storage, aggregation, alerts  
✅ **Dashboard Architecture** — Web UI, backend API, real-time updates  
✅ **Phased Implementation** — 3 phases, 6 weeks total, ~210 hours  
✅ **Detailed Code** — Phase 1 fully specified with working examples  
✅ **Testing Strategy** — Unit & integration tests outlined  
✅ **Config Templates** — YAML rules, pricing, alert thresholds  

**Ready to build. Let's go. 🧑‍🎄**

---

**Next Step:** mas Aris reviews this plan. Questions? Start Phase 1 implementation? Want to adjust scope/timeline?

