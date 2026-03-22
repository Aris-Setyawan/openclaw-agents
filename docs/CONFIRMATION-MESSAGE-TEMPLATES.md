# Confirmation Message Templates

**Purpose:** Standard confirmation messages sebelum eksekusi expensive/risky operations.

**MUST INCLUDE:**
- Action yang akan dilakukan
- Provider & model yang dipakai
- Cost estimate
- Risks/warnings
- How to approve/deny

---

## 🎬 Video Generation Confirmation

### Template (kie.ai Veo3 - Default)

```
🚨 CONFIRMATION REQUIRED 🚨

╔══════════════════════════════════════╗
║   VIDEO GENERATION REQUEST           ║
╚══════════════════════════════════════╝

📹 Action: Generate video
📝 Prompt: "[user prompt here]"
⏱️  Duration: 6 seconds
📐 Aspect ratio: 16:9

🤖 Provider: kie.ai
🎨 Model: Veo3 Fast
💰 Cost: ~Rp 10,000 - Rp 15,000
📊 Audio: ✅ Included (no extra charge)

⚠️  This action:
  • Costs money
  • Cannot be undone
  • Takes ~1-3 minutes to complete

Reply:
  • 'yes' or 'y' → Proceed
  • 'no' or 'n' → Cancel
```

### Template (Google Veo - Premium)

```
🚨 CONFIRMATION REQUIRED 🚨

╔══════════════════════════════════════╗
║   VIDEO GENERATION REQUEST           ║
║   (PREMIUM QUALITY)                  ║
╚══════════════════════════════════════╝

📹 Action: Generate video (premium)
📝 Prompt: "[user prompt here]"
⏱️  Duration: [5-8] seconds
📐 Aspect ratio: 16:9

🤖 Provider: Google Cloud Vertex AI
🎨 Model: Veo 3.0 Fast Generate 001
💰 Cost: ~Rp 18,000 - Rp 23,000
📊 Breakdown:
  - Video output: ~Rp 3,000 - Rp 8,000
  - Audio output: ~Rp 15,000 (charged separately!)

⚠️  This action:
  • Costs 2x more than kie.ai
  • Audio charged separately
  • Cannot be undone
  • Takes ~1-3 minutes to complete

💡 Tip: Use kie.ai for same quality at half price!

Reply:
  • 'yes' → Proceed with Google Veo (expensive)
  • 'no' → Cancel
  • 'kie' → Switch to kie.ai Veo3 (cheaper)
```

---

## 🖼️ Image Generation Confirmation

### Template (Gemini Imagen 3 - Default)

```
🚨 CONFIRMATION REQUIRED 🚨

╔══════════════════════════════════════╗
║   IMAGE GENERATION REQUEST           ║
╚══════════════════════════════════════╝

🖼️  Action: Generate image
📝 Prompt: "[user prompt here]"
📐 Size: 1024x1024 (1K resolution)
🎨 Style: Photorealistic

🤖 Provider: Google Gemini
🎨 Model: Imagen 3
💰 Cost: ~Rp 1,000 - Rp 5,000

⚠️  This action:
  • Costs money
  • Cannot be undone
  • Takes ~10-30 seconds

Reply:
  • 'yes' or 'y' → Proceed
  • 'no' or 'n' → Cancel
```

### Template (kie.ai Flux Kontext - Fallback)

```
🚨 CONFIRMATION REQUIRED 🚨

╔══════════════════════════════════════╗
║   IMAGE GENERATION REQUEST           ║
║   (Gemini unavailable, using fallback)║
╚══════════════════════════════════════╝

🖼️  Action: Generate image
📝 Prompt: "[user prompt here]"
📐 Size: 1024x1024
🎨 Style: High-quality AI image

🤖 Provider: kie.ai
🎨 Model: Flux Kontext Pro
💰 Cost: ~Rp 2,000 - Rp 4,000

⚠️  This action:
  • Costs money (fallback provider)
  • Cannot be undone
  • Takes ~30-60 seconds

Reply:
  • 'yes' or 'y' → Proceed
  • 'no' or 'n' → Cancel
```

---

## 🎤 Audio/TTS Generation Confirmation

### Template (Google Gemini TTS - Default)

```
🚨 CONFIRMATION REQUIRED 🚨

╔══════════════════════════════════════╗
║   AUDIO GENERATION REQUEST           ║
╚══════════════════════════════════════╝

🎤 Action: Generate audio/voice
📝 Text: "[user text here]"
🗣️  Voice: [Aoede/Charon/etc.]
⏱️  Estimated duration: ~[X] seconds

🤖 Provider: Google Gemini
🎨 Model: Gemini 2.5 Flash Preview TTS
💰 Cost: ~Rp 500 - Rp 2,000

⚠️  This action:
  • Costs money (minimal)
  • Cannot be undone
  • Takes ~5-15 seconds

Reply:
  • 'yes' or 'y' → Proceed
  • 'no' or 'n' → Cancel
```

---

## 🗑️ File Deletion Confirmation

```
🚨 CONFIRMATION REQUIRED 🚨

╔══════════════════════════════════════╗
║   FILE DELETION WARNING              ║
╚══════════════════════════════════════╝

🗑️  Action: Delete file
📄 File: [file path]
📊 Size: [file size]
📅 Modified: [last modified date]

⚠️  DANGER:
  • This action is IRREVERSIBLE
  • File will be permanently deleted
  • Cannot be recovered (unless using trash)

💡 Tip: Use 'trash' instead for recovery option

Reply:
  • 'yes' → DELETE permanently
  • 'no' → Cancel
  • 'trash' → Move to trash (recoverable)
```

---

## 📝 Critical File Edit Confirmation

```
🚨 CONFIRMATION REQUIRED 🚨

╔══════════════════════════════════════╗
║   CRITICAL FILE EDIT WARNING         ║
╚══════════════════════════════════════╝

📝 Action: Edit critical file
📄 File: [AGENTS.md/TOOLS.md/SOUL.md/etc.]
🔧 Changes:
  [Summary of what will be changed]

⚠️  WARNING:
  • This file affects agent behavior
  • Incorrect edits can break functionality
  • Backup recommended before proceeding

💡 Tip: Git tracks changes, can revert if needed

Reply:
  • 'yes' → Proceed with edit
  • 'no' → Cancel
  • 'backup' → Create backup first, then edit
```

---

## 📧 External Communication Confirmation

```
🚨 CONFIRMATION REQUIRED 🚨

╔══════════════════════════════════════╗
║   EXTERNAL COMMUNICATION WARNING     ║
╚══════════════════════════════════════╝

📧 Action: Send message externally
🎯 Destination: [email/tweet/etc.]
👤 Recipient: [recipient info]
📝 Message preview:
  "[first 100 chars...]"

⚠️  WARNING:
  • This action is PUBLIC/EXTERNAL
  • Cannot be undone once sent
  • Represents you to others

Reply:
  • 'yes' → Send
  • 'no' → Cancel
  • 'show' → Show full message first
```

---

## ⚡ Shell Command Confirmation (Outside Workspace)

```
🚨 CONFIRMATION REQUIRED 🚨

╔══════════════════════════════════════╗
║   SHELL COMMAND WARNING              ║
╚══════════════════════════════════════╝

⚡ Action: Execute shell command
📍 Location: [directory outside workspace]
💻 Command: [command to run]

⚠️  WARNING:
  • This command runs outside workspace
  • Potential system-wide impact
  • May require elevated permissions

Reply:
  • 'yes' → Execute
  • 'no' → Cancel
  • 'dry-run' → Show what would happen (if supported)
```

---

## 📦 Bulk Operation Confirmation

```
🚨 CONFIRMATION REQUIRED 🚨

╔══════════════════════════════════════╗
║   BULK OPERATION WARNING             ║
╚══════════════════════════════════════╝

📦 Action: [Bulk delete/edit/process]
📊 Affected items: [count] files/objects
💰 Total cost: ~Rp [total estimate]
⏱️  Estimated time: ~[time]

📋 Summary:
  [List of affected items or preview]

⚠️  WARNING:
  • This affects multiple items at once
  • Cannot be undone
  • May take significant time/cost

Reply:
  • 'yes' → Proceed with all
  • 'no' → Cancel entire operation
  • 'preview' → Show full list first
```

---

## 🎯 Usage Guidelines

### When to Show Confirmation:

**ALWAYS (Level 3 - Hard Confirm):**
- Image generation (~Rp 1-5K)
- Video generation (~Rp 10-23K)
- Audio generation (~Rp 0.5-2K)
- File deletion
- Edit critical files
- External communication
- Shell commands outside workspace

**SOMETIMES (Level 2 - Soft Confirm):**
- Create new files (first time in session)
- Download large files
- Install packages

**NEVER (Level 1 - No Confirm):**
- Read files
- List directories
- Check status
- Search web

### Information to Include:

1. **Provider & Model** → kie.ai Veo3, Google Veo, Gemini Imagen, etc.
2. **Cost estimate** → Range in Rupiah
3. **Cost breakdown** → If multiple charges (video + audio)
4. **Risks** → Irreversible, public, expensive, etc.
5. **Alternatives** → Cheaper options if available
6. **Clear yes/no options** → How to approve or deny

### Format Rules:

- Use emoji for visual clarity
- Box headers for important sections
- Bullet points for warnings
- Show cost prominently
- Provide clear yes/no options
- Suggest alternatives when applicable

---

## 🔄 Response Handling

After sending confirmation, agent MUST:
1. **Wait for user reply** (next message)
2. **Check reply** with `check-user-approval.sh`
3. **Execute ONLY if approved**
4. **Respect denial/cancellation**

If user says unclear response → ask for clarification:
```
❓ Tidak jelas, mas Aris.

Reply:
  • 'yes' → Saya lanjutkan
  • 'no' → Saya batalkan
```

---

## References

- Skill: `/root/.openclaw/workspace/skills/confirm-before-action/SKILL.md`
- Approval checker: `/root/.openclaw/workspace/scripts/check-user-approval.sh`
- Rules: `AGENTS.md` (Red Lines section)
