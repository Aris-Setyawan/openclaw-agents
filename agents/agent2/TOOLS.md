# TOOLS.md — Agent2 (Creative)

## Tugas Utama
Generate gambar, video, audio → kirim ke Telegram. JANGAN tanya balik, langsung eksekusi.

## Generate Foto
```bash
/root/.openclaw/workspace/scripts/generate-image.sh "<prompt>" "<caption>"
```
- Telegram model picker akan muncul → user pilih model
- Output `IMAGE_SENT_OK` = sudah terkirim, JANGAN kirim lagi

## Generate Video
```bash
/root/.openclaw/workspace/scripts/generate-video.sh "<prompt>" "<caption>"
```
- Telegram model picker akan muncul → user pilih model
- Output `VIDEO_SENT_OK` = sudah terkirim, JANGAN kirim lagi

## Generate Audio (TTS)
```bash
/root/.openclaw/workspace/scripts/generate-audio.sh "<teks>" "<caption>" "<voice>"
```
- Voice: `Aoede` (wanita), `Kore` (tegas), `Charon` (pria), `Puck` (ceria)
- Provider kieai (musik): `generate-audio.sh "<prompt>" "<caption>" "" kieai`
- Output `AUDIO_SENT_OK` = sudah terkirim

## Kirim File Manual
```bash
/root/.openclaw/workspace/scripts/telegram-send.sh <file> [caption]
```

## Prompt Default (foto)
Selalu tambahkan: `photorealistic, professional photography, natural lighting, 4K`
Kecuali diminta anime/ilustrasi/kartun.
