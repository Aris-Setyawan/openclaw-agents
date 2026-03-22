# Video Generation Cost Optimization

**Date:** 2026-03-22  
**Trigger:** Google Cloud billing Rp 60K for audio (4 videos)

---

## Problem Discovery

Google Veo charges **VIDEO + AUDIO SEPARATELY**:
- Video output: ~Rp 3-8K
- **Audio output: ~Rp 15K per video** 😱
- **TOTAL: ~Rp 18-23K per video** (not Rp 3K as expected!)

**Evidence:**
- 4 videos × Rp 15K audio = Rp 60K billing ✅
- This is normal Google Veo pricing, NOT a bug

---

## Solution: Switch Default to kie.ai

### Cost Comparison

| Provider | Video | Audio | Total | Savings |
|----------|-------|-------|-------|---------|
| **kie.ai Veo3 Fast** | Rp 10-15K | ✅ Included | **Rp 10-15K** | — |
| Google Veo 3 Fast | Rp 3-8K | ❌ Rp 15K | Rp 18-23K | **-40%** |
| Google Veo 3 Std | Rp 20-30K | ❌ Rp 15K | Rp 35-45K | **-70%** |

### Changes Implemented

**1. Script Refactor (`generate-video.sh`):**
```bash
# NEW DEFAULT (kie.ai)
/root/.openclaw/workspace/scripts/generate-video.sh "prompt" "caption"

# EXPLICIT GOOGLE (expensive)
/root/.openclaw/workspace/scripts/generate-video.sh "prompt" "caption" "google"
```

**2. Updated Limits:**
- kie.ai videos: Max **5/day** (affordable)
- Google videos: Max **2/day** (expensive)
- Images: Max **10/day** (unchanged)

**3. Documentation:**
- `TOOLS.md` updated with provider comparison
- Cost awareness section with breakdown
- Daily limits adjusted

---

## Benefits

✅ **Save ~40-50% per video** (Rp 8-13K per video)  
✅ **No separate audio charge** (predictable cost)  
✅ **Same quality** for casual/quick content  
✅ **Google still available** for premium needs  
✅ **Monitoring active** (usage logged)

---

## Usage Guide

### Default (kie.ai - Recommended)
```bash
/root/.openclaw/workspace/scripts/generate-video.sh \
  "wanita tersenyum di taman, sinematik, 4K" \
  "Video Wulan 🎬"
```

### Google Veo (Premium Quality)
```bash
/root/.openclaw/workspace/scripts/generate-video.sh \
  "prompt dengan detail tinggi" \
  "Caption" \
  "google" \
  8
```

### Direct Mode (No Agent Context)
```bash
/root/.openclaw/workspace/scripts/generate-video-direct.sh \
  "prompt" \
  "caption" \
  "kieai"
```

---

## Monthly Savings Estimate

**Before (Google Veo only):**
- 30 videos/month × Rp 20K = **Rp 600K**

**After (kie.ai default):**
- 30 videos/month × Rp 12K = **Rp 360K**
- **Savings: Rp 240K/month (40%!)** 🎉

---

## Monitoring

Check usage anytime:
```bash
/root/.openclaw/workspace/scripts/check-api-health.sh 24
```

View logs:
```bash
tail -f /root/.openclaw/workspace/logs/api-usage.log
```

---

## References

- Google Veo pricing: https://cloud.google.com/vertex-ai/pricing
- kie.ai pricing: https://kie.ai/pricing
- Implementation: `/root/.openclaw/workspace/scripts/generate-video.sh`
- Memory: `/root/.openclaw/workspace/memory/2026-03-22.md`
