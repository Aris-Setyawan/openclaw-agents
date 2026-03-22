# Auto-Report Skill

**Purpose:** Ensure agents ALWAYS report task completion without needing to be asked.

**Trigger:** When delegating tasks to other agents (agent2, agent3, agent4) for long-running work.

---

## Problem

When Agent1 delegates to Agent2/3/4 via `openclaw agent --agent agentX`, the delegated agent:
- ✅ Does the work
- ✅ Returns result
- ❌ **Does NOT proactively announce to user**

User has to manually ask "sudah selesai?" to get the update.

---

## Solution

### 1. Wrapper Script dengan Auto-Announce

Create wrapper that:
1. Delegate task to target agent
2. Wait for completion
3. **Auto-send result to Telegram** (user's active channel)
4. Return result to caller

**Location:** `/root/.openclaw/workspace/scripts/delegate-with-report.sh`

**Usage:**
```bash
/root/.openclaw/workspace/scripts/delegate-with-report.sh \
  "agent2" \
  "Generate image: wanita tersenyum" \
  "Task selesai: Gambar sudah dibuat! 🎨"
```

---

### 2. Agent Rules (AGENTS.md)

Add to **AGENTS.md** delegation section:

```markdown
## 📣 Auto-Reporting Rules (WAJIB!)

Setelah delegate task ke agent lain:
1. JANGAN tunggu user tanya
2. LANGSUNG kasih update begitu selesai
3. Format: "✅ Task selesai: [summary]"
4. Kirim ke Telegram otomatis via script

**Workflow:**
- User: "Buatin video Wulan minum kopi"
- Agent1: Delegate ke agent2
- Agent2: Generate video (1-3 menit)
- **Agent1: "✅ Video selesai dan sudah dikirim! 🎬"** ← AUTO!
- User: Tidak perlu tanya, langsung dapat update

**Implementation:**
Use `delegate-with-report.sh` instead of direct `openclaw agent`
```

---

### 3. Update Existing Scripts

Modify `generate-image.sh`, `generate-video.sh`, etc. to:
- Echo completion status to stdout
- Caller script catches this and announces to user

---

## Implementation

### Step 1: Create Wrapper Script

```bash
#!/bin/bash
# delegate-with-report.sh
# Usage: delegate-with-report.sh <target_agent> <task> <completion_msg>

TARGET_AGENT="$1"
TASK="$2"
COMPLETION_MSG="$3"

OPENCLAW=/www/server/nvm/versions/node/v22.20.0/bin/openclaw

echo "🔄 Delegating to $TARGET_AGENT..." >&2

# Execute task (synchronous)
RESULT=$($OPENCLAW agent --agent "$TARGET_AGENT" --message "$TASK" 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
  # Success - announce to user
  echo "✅ $COMPLETION_MSG" >&2
  
  # Optional: Send to Telegram directly
  # /root/.openclaw/workspace/scripts/telegram-send.sh "" "$COMPLETION_MSG"
  
  echo "$RESULT"
  exit 0
else
  # Failure - report error
  echo "❌ Task gagal: $RESULT" >&2
  exit 1
fi
```

### Step 2: Update AGENTS.md

Add auto-reporting rules to delegation section.

### Step 3: Update TOOLS.md

Replace direct `openclaw agent` calls with `delegate-with-report.sh` wrapper.

---

## Benefits

✅ User gets immediate updates when tasks complete  
✅ No need to ask "sudah selesai?"  
✅ Better UX for long-running tasks (video gen, analysis, etc.)  
✅ Consistent reporting format  
✅ Easy to extend (add notifications, logs, etc.)

---

## Example Workflow

**Before (manual):**
```
User: "Buatin video Wulan"
Agent1: [delegates to agent2]
Agent2: [generates video 2 minutes...]
Agent2: [done, waits silently]
User: "Sudah selesai?"
Agent1: "Iya sudah, videonya sudah dikirim"
```

**After (auto):**
```
User: "Buatin video Wulan"
Agent1: [delegates via wrapper]
Agent2: [generates video 2 minutes...]
Agent1: "✅ Video selesai dan sudah dikirim! 🎬"
User: [happy, no need to ask]
```

---

## References

- Wrapper script: `/root/.openclaw/workspace/scripts/delegate-with-report.sh`
- Agent rules: `/root/.openclaw/workspace/AGENTS.md`
- Tools usage: `/root/.openclaw/workspace/TOOLS.md`
