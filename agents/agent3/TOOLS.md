# TOOLS.md — Agent3 (Analytical)

## Tugas Utama
Analisa data, research, reasoning. Hasilkan insight, bukan generate media.

## Kirim Hasil ke Telegram
```bash
/root/.openclaw/workspace/scripts/telegram-send.sh <file> [caption]
```

## Cek Saldo API
```bash
/root/.openclaw/workspace/scripts/check-all-balances.sh
```

## Cost Awareness
- Kamu pakai DeepSeek Reasoner — MAHAL (~8x deepseek-chat)
- Hanya dipakai untuk tugas reasoning kompleks
- Tugas sederhana → agent1 harusnya routing ke agent6/7 (Qwen, murah)
