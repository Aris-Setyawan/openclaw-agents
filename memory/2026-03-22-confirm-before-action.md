# 2026-03-22 Confirm Before Action Implementation

## 04:43 UTC - User Complaint: No Confirmation Before Expensive/Destructive Actions

**User complaint:**
> "Nah, sebelum eksekusi perintah jga apakah sudah jalanin konfirmasi? Seperti ny kmren saat saya buat video langsung generate aja, GK ada konfirmasi sama sekali? Tiap jalanin perintah langsung eksekusi dan GK bisa berhenti, sama sekali. Kadang file penting di edit dan dihapus tanpa persetujuan. Dan tidak bisa di hentikan ditengah jalan"

**Problems:**
1. ❌ No confirmation before video generation (~Rp 15K)
2. ❌ No confirmation before file deletion
3. ❌ No confirmation before editing important files
4. ❌ Cannot stop operations mid-way
5. ❌ Agent auto-executes without showing cost/risks

**Impact:**
- Unexpected API charges
- Lost files
- User frustration
- Lack of control

---

## Solution Implemented ✅

### 1. Confirmation Skill

**Location:** `/root/.openclaw/workspace/skills/confirm-before-action/SKILL.md`

**Defines 4 levels:**
- Level 1: No confirmation (read-only ops)
- Level 2: Soft confirm (low-risk ops)
- Level 3: Hard confirm (expensive/risky ops)
- Level 4: Veto (never auto-execute)

### 2. Scripts Created

#### `confirm-action.sh` (Interactive Terminal)
- For interactive shell usage
- Shows confirmation prompt with cost
- Returns 0 (approved) or 1 (denied)
- **Limitation:** Doesn't work in Telegram bot context

#### `request-confirmation.sh` (Telegram Bot)
- Sends confirmation message to Telegram
- Shows action, cost, risks
- User replies in next message
- **Better for bot usage**

#### `check-user-approval.sh` (Parse User Reply)
- Check if user message contains approval
- Detects: yes/y/ya/ok/proceed/lanjut/etc.
- Detects denial: no/n/tidak/cancel/stop/etc.
- Returns: 0 (approved), 1 (denied), 2 (unclear)

### 3. Agent Rules Updated

**AGENTS.md:**
- NEW "Red Lines (ENFORCED!)" section
- NEVER auto-execute list (image/video gen, file deletion, etc.)
- ALWAYS confirm first workflow
- User can cancel anytime rules
- Before/after examples

**SOUL.md:**
- Updated Boundaries to include confirmation requirement
- Show cost BEFORE executing
- Respect user cancellation

### 4. Confirmation Workflow

**OLD (BAD ❌):**
```
User: "Buatin video Wulan"
Agent: [langsung generate tanpa tanya]
Cost: Rp 15K charged
User: [surprised, upset]
```

**NEW (GOOD ✅):**
```
User: "Buatin video Wulan"
Agent: 🚨 CONFIRMATION REQUIRED
       Action: Generate video via kie.ai
       Prompt: "Wulan minum kopi"
       Cost: ~Rp 15,000
       Duration: 6 seconds
       
       This costs money and cannot be undone.
       
       Reply 'yes' to proceed or 'no' to cancel.

User: "yes"
Agent: ✅ Confirmed. Generating video...
       [execute]
       ✅ Video selesai dan sudah dikirim! 🎬
```

---

## Implementation Status

| Component | Status | Location |
|-----------|--------|----------|
| Skill documentation | ✅ | `skills/confirm-before-action/SKILL.md` |
| Confirmation script (interactive) | ✅ | `scripts/confirm-action.sh` |
| Confirmation script (Telegram) | ✅ | `scripts/request-confirmation.sh` |
| Approval checker | ✅ | `scripts/check-user-approval.sh` |
| AGENTS.md update | ✅ | Red Lines enforcement section |
| SOUL.md update | ✅ | Boundaries update |
| Integration into scripts | ⏳ | **TODO: Needs manual integration** |

---

## Next Steps (CRITICAL!)

### Immediate (Must Do):

1. **Agent behavior change:**
   - Before ANY expensive/risky operation:
     - Send confirmation message
     - WAIT for user reply (don't execute yet)
     - Check reply with `check-user-approval.sh`
     - Only execute if approved

2. **Common operations to protect:**
   - `generate-video.sh` → ask before submit
   - `generate-image.sh` → ask before submit
   - File deletion → ask before delete
   - Edit AGENTS.md/TOOLS.md/SOUL.md → ask before edit

### Integration Example:

**In agent logic (before calling generate-video.sh):**
```
1. Detect user wants video generation
2. Send confirmation message via Telegram:
   "🚨 CONFIRMATION REQUIRED
    Action: Generate video
    Cost: ~Rp 15K
    Reply 'yes' to proceed"
3. Return NO_REPLY (wait for next message)
4. User replies "yes"
5. Check reply with check-user-approval.sh
6. If approved → execute generate-video.sh
7. If denied → reply "❌ Cancelled"
```

### Optional (Future):

- Add timeout (auto-cancel after 5 minutes)
- Remember user preferences ("always confirm videos")
- Add interrupt handler to long operations (Ctrl+C equivalent)
- Confirmation history log

---

## Test Results

**Approval checker:**
```bash
$ echo "yes" | check-user-approval.sh
✅ Approval detected (exit 0)

$ echo "no" | check-user-approval.sh
❌ Denial detected (exit 1)

$ echo "maybe" | check-user-approval.sh
❓ Unclear response - need explicit yes/no (exit 2)
```
✅ **WORKING!**

---

## Benefits

✅ **User control** - No surprise costs  
✅ **Transparency** - Know cost before committing  
✅ **Safety** - Can't accidentally delete files  
✅ **Trust** - Agent won't do things behind back  
✅ **Cancellable** - Can stop anytime

---

## Critical Note

**⚠️ AGENT MUST CHANGE BEHAVIOR!**

Scripts are ready, but **agent must actually USE them**!

**Before this is enforced in code:**
- Agent must manually send confirmation messages
- Agent must manually wait for user reply
- Agent must manually check approval

**This requires:**
- Agent awareness of rules (AGENTS.md, SOUL.md)
- Agent discipline to follow rules
- OR: Integration into generate-*.sh scripts directly

---

## References

- Skill: `/root/.openclaw/workspace/skills/confirm-before-action/SKILL.md`
- Scripts: `scripts/confirm-action.sh`, `request-confirmation.sh`, `check-user-approval.sh`
- Rules: `AGENTS.md` (Red Lines section), `SOUL.md` (Boundaries)
- User complaint: 2026-03-22 04:43 UTC
