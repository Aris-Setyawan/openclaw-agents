# Model Usage Monitoring & Alerts

**Created:** 2026-03-22  
**Purpose:** Detect usage spikes & fallback events automatically

---

## 🎯 Features

### 1. Usage Spike Detection
- Monitor DeepSeek & OpenRouter usage hourly
- Alert when usage exceeds thresholds
- Project daily/monthly costs
- Send Telegram notifications

### 2. Fallback Logging
- Log when primary model fails
- Track fallback model usage
- Alert user immediately
- Help diagnose issues

---

## 📊 Monitoring Script

**Location:** `/root/.openclaw/workspace/scripts/monitor-model-usage.sh`

**What it does:**
- Checks DeepSeek & OpenRouter balance/usage
- Compares with previous check
- Calculates hourly usage rate
- Sends alert if exceeds threshold

**Thresholds:**
- DeepSeek: **$0.10/hour** (= $2.40/day, $72/month)
- OpenRouter: **$0.02/hour** (= $0.48/day, $14.4/month)

**Run manually:**
```bash
/root/.openclaw/workspace/scripts/monitor-model-usage.sh
```

**Automated:** Runs every hour via cron job

---

## 🚨 Alert Format

### Usage Spike Alert

```
🚨 API USAGE ALERT

[Provider] USAGE SPIKE!

Used: $X.XX in Yh
Rate: ~$Z.ZZ/hour

Projected:
- Daily: ~$A.AA/day
- Monthly: ~$B.BB/month

Current balance: $C.CC

⚠️  [Warning message & suggested actions]

Time: YYYY-MM-DD HH:MM UTC
```

**Delivery:** Telegram notification

---

## ⚠️ Fallback Logger

**Location:** `/root/.openclaw/workspace/scripts/log-model-fallback.sh`

**Usage:**
```bash
log-model-fallback.sh <agent> <primary_model> <fallback_model> [reason]
```

**Example:**
```bash
log-model-fallback.sh \
  agent1 \
  "gemini-2.5-flash" \
  "openrouter/gemini" \
  "rate_limit"
```

**What it does:**
1. Logs fallback event to `/root/.openclaw/workspace/logs/model-fallback.log`
2. Sends Telegram notification with details
3. Includes impact & action recommendations

---

## 📋 Alert Examples

### Example 1: DeepSeek Spike

```
🚨 API USAGE ALERT

DeepSeek USAGE SPIKE!

Used: $0.50 in 2h
Rate: ~$0.25/hour

Projected:
- Daily: ~$6.00/day
- Monthly: ~$180/month

Current balance: $2.29

⚠️  Check for context bloat or excessive calls!

Time: 2026-03-22 14:00 UTC
```

**Action:** Investigate context size, limit requests, check logs

---

### Example 2: OpenRouter Fallback

```
⚠️ MODEL FALLBACK DETECTED

Agent: agent1
Primary: gemini-2.5-flash (FAILED)
Fallback: openrouter/gemini-2.5-flash (ACTIVE)
Reason: rate_limit

Time: 2026-03-22 11:36 UTC

Impact:
- Cost may increase (fallback often more expensive)
- Check primary model status
- Review logs: tail /root/.openclaw/workspace/logs/model-fallback.log

Action:
- If temporary: Primary will auto-recover
- If persistent: Check API key, rate limits, quota
```

**Action:** Check Gemini Direct API status, wait for recovery, or investigate quota

---

## 📂 Log Files

### Usage State
```
/root/.openclaw/workspace/logs/model-usage-state.json
```
Tracks last check timestamp, balances, usage rates

### Fallback Log
```
/root/.openclaw/workspace/logs/model-fallback.log
```
Records all fallback events with timestamp, agent, models, reason

### Alert Log
```
/root/.openclaw/workspace/logs/model-alerts.log
```
Records all spike alerts sent

---

## ⏰ Automation

### Cron Job: Hourly Monitor

**Schedule:** Every hour (0 minutes past the hour)  
**Job ID:** `f91ddcb6-9817-4c8b-816f-b290c0a81cc7`  
**Action:** Run monitor script, report alerts if any

**Cron expression:** `0 * * * *` (UTC)

**Delivery:** Telegram announce

**Check status:**
```bash
openclaw cron list
```

**Disable:**
```bash
openclaw cron update f91ddcb6-9817-4c8b-816f-b290c0a81cc7 --enabled false
```

---

## 🔧 Manual Checks

### Check current usage
```bash
/root/.openclaw/workspace/scripts/check-all-balances.sh
```

### Monitor usage over time
```bash
/root/.openclaw/workspace/scripts/monitor-model-usage.sh
```

### View fallback history
```bash
cat /root/.openclaw/workspace/logs/model-fallback.log
```

### View alerts
```bash
cat /root/.openclaw/workspace/logs/model-alerts.log
```

---

## 🎯 Thresholds (Configurable)

Edit thresholds in `monitor-model-usage.sh`:

```bash
DEEPSEEK_THRESHOLD="0.10"     # $/hour
OPENROUTER_THRESHOLD="0.02"   # $/hour
```

**Recommendations:**
- **Low budget:** Set to $0.05 (DeepSeek), $0.01 (OpenRouter)
- **Medium budget:** Current ($0.10, $0.02)
- **High budget:** Increase to $0.20, $0.05

---

## 📊 Dashboard (Future)

Planned features:
- Web dashboard for usage visualization
- Historical usage graphs
- Cost breakdown by agent
- Real-time model status

---

## References

- Monitor script: `/root/.openclaw/workspace/scripts/monitor-model-usage.sh`
- Fallback logger: `/root/.openclaw/workspace/scripts/log-model-fallback.sh`
- Cron job: `openclaw cron list | grep "Model Usage"`
- This doc: `/root/.openclaw/workspace/docs/MODEL-MONITORING-ALERTS.md`
