# Confirm Before Action Skill

**Purpose:** ALWAYS ask user confirmation before executing expensive, destructive, or irreversible operations.

**Trigger:** Before any action that costs money, deletes data, or can't be undone.

---

## Problem

Agent currently executes commands immediately without confirmation:
- ❌ Generate video → langsung execute (~Rp 15K)
- ❌ Delete files → langsung hapus
- ❌ Edit important files → langsung edit
- ❌ Tidak bisa di-stop ditengah jalan

**User complaint (Mar 22, 2026):**
> "Tiap jalanin perintah langsung eksekusi dan GK bisa berhenti, sama sekali. Kadang file penting di edit dan dihapus tanpa persetujuan. Dan tidak bisa di hentikan ditengah jalan"

---

## Solution

### Level-Based Confirmation System

#### **LEVEL 1: NO CONFIRMATION (Safe Operations)**
- ✅ Read files
- ✅ Search web
- ✅ Check status
- ✅ List files
- ✅ Show info

#### **LEVEL 2: SOFT CONFIRM (Low Risk, Low Cost)**
**Ask once, remember choice for session:**
- ⚠️ Create new files
- ⚠️ Simple edits to workspace files
- ⚠️ Run analysis scripts
- ⚠️ Download public data

**Format:**
```
🤔 About to: Create new file 'test.md'
Continue? [Y/n/always/never]:
```

#### **LEVEL 3: HARD CONFIRM (High Risk or High Cost)**
**ALWAYS ask, NEVER remember:**
- 🚨 Generate image (~Rp 1-5K)
- 🚨 Generate video (~Rp 15K)
- 🚨 Delete files
- 🚨 Edit AGENTS.md, TOOLS.md, SOUL.md
- 🚨 Send emails/messages externally
- 🚨 Execute shell commands outside workspace
- 🚨 API calls that cost money

**Format:**
```
🚨 CONFIRMATION REQUIRED 🚨

Action: Generate video via kie.ai Veo3
Cost: ~Rp 15,000
Prompt: "wanita tersenyum di taman"
Duration: 6 seconds

This action:
- Costs money
- Cannot be undone
- Will take 1-3 minutes

Proceed? [y/N]:
```

#### **LEVEL 4: VETO (Never Auto-Execute)**
**ALWAYS show plan first, wait for explicit approval:**
- 🔒 Bulk operations (delete >5 files)
- 🔒 Irreversible changes
- 🔒 Production deployments
- 🔒 Anything involving credentials

---

## Implementation

### 1. Wrapper Function: `confirm_action()`

**Location:** `/root/.openclaw/workspace/scripts/confirm-action.sh`

**Usage:**
```bash
# Before expensive operation:
if ! /root/.openclaw/workspace/scripts/confirm-action.sh \
  "Generate video" \
  "~Rp 15K" \
  "This will generate a 6-second video via kie.ai"; then
  echo "❌ Operation cancelled by user"
  exit 1
fi

# Continue with operation...
generate_video.sh "prompt" "caption"
```

### 2. Integration Points

**generate-video.sh:**
```bash
# Add at top of script (after arg parsing)
if ! /root/.openclaw/workspace/scripts/confirm-action.sh \
  "Generate video: $PROMPT" \
  "~Rp 10-15K (kie.ai) or ~Rp 20K (Google)" \
  "Duration: ${DURATION}s, Provider: $PROVIDER"; then
  exit 1
fi
```

**generate-image.sh:**
```bash
# Add before actual generation
if ! /root/.openclaw/workspace/scripts/confirm-action.sh \
  "Generate image: ${PROMPT:0:50}..." \
  "~Rp 1-5K" \
  "Photorealistic image via Gemini Imagen"; then
  exit 1
fi
```

**file deletions:**
```bash
# Before rm/trash
if ! /root/.openclaw/workspace/scripts/confirm-action.sh \
  "Delete file: $FILE" \
  "Irreversible (or use trash for recovery)" \
  "File: $FILE"; then
  exit 1
fi
```

### 3. Agent Rules (AGENTS.md)

Add new "Red Lines" enforcement:

```markdown
## 🚨 Confirmation Rules (ENFORCED! - Mar 22, 2026)

**NEVER auto-execute without asking:**

1. **Image/Video Generation** → costs money (~Rp 1-20K)
2. **File Deletion** → irreversible
3. **Edit Critical Files** → AGENTS.md, TOOLS.md, SOUL.md, MEMORY.md
4. **External Communication** → emails, tweets, messages
5. **Shell Commands** → outside workspace directory

**ALWAYS show plan first:**
- What will happen
- Cost (if applicable)
- Risks
- How to undo (if possible)

**Wait for explicit approval:**
- "yes" / "y" / "proceed" / "ok"
- NOT "probably" or "I think so"
- Default to NO if unclear

**User can cancel anytime:**
- During confirmation prompt
- By saying "stop" / "cancel" / "wait"
- Between steps of multi-step operations
```

### 4. Stop Mechanism

Add interrupt handler to long-running scripts:

```bash
# At top of generate-video.sh, generate-image.sh
trap "echo '⚠️ Interrupted by user'; exit 130" INT TERM

# During polling loops:
echo "⏳ Generating... (Press Ctrl+C to cancel)"
```

---

## Examples

### Good Confirmation Flow

**User:** "Buatin video Wulan minum kopi"

**Agent:**
```
🚨 CONFIRMATION REQUIRED 🚨

Action: Generate video via kie.ai Veo3
Prompt: "Wulan sedang minum kopi, sinematik, natural lighting"
Cost: ~Rp 15,000
Duration: 6 seconds
Time: ~2 minutes

This action costs money and cannot be undone.

Proceed? [y/N]:
```

**User:** "y"

**Agent:**
```
✅ Confirmed. Generating video...
⏳ Progress: Submitting to kie.ai Veo3...
⏳ Progress: Waiting for generation (0:15)...
⏳ Progress: Waiting for generation (0:30)...
✅ Video selesai dan sudah dikirim! 🎬
```

### Cancellation Flow

**User:** "wait, cancel that"

**Agent:**
```
⚠️ Cancellation requested
❌ Operation stopped
Video generation cancelled before submission.
No charges incurred.
```

---

## Benefits

✅ **User control** - No surprise costs or deletions  
✅ **Transparency** - Always know what will happen before it happens  
✅ **Cost awareness** - See price before committing  
✅ **Safety** - Can't accidentally delete important files  
✅ **Interrupts** - Can stop long operations mid-way  
✅ **Trust** - Agent won't do things behind user's back

---

## References

- Confirmation script: `/root/.openclaw/workspace/scripts/confirm-action.sh`
- Agent rules: `/root/.openclaw/workspace/AGENTS.md`
- Integration: `generate-video.sh`, `generate-image.sh`, etc.
- User request: 2026-03-22 04:43 UTC
