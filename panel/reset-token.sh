#!/usr/bin/env bash
# Reset panel token via CLI — untuk situasi lupa token / tidak bisa login
# Usage:
#   ./reset-token.sh              → reset ke default (openclaw-panel-2026)
#   ./reset-token.sh mytoken123   → set token baru

TOKEN_FILE="/root/.openclaw/panel-token.txt"
DEFAULT="openclaw-panel-2026"
NEW_TOKEN="${1:-$DEFAULT}"

if [ ${#NEW_TOKEN} -lt 8 ]; then
    echo "❌ Token minimal 8 karakter"
    exit 1
fi

echo "$NEW_TOKEN" > "$TOKEN_FILE"
echo "✓ Token file updated: $NEW_TOKEN"

# Restart panel agar token terbaca dari file
if systemctl is-active --quiet openclaw-panel 2>/dev/null; then
    systemctl restart openclaw-panel
    sleep 1
    if systemctl is-active --quiet openclaw-panel; then
        echo "✓ Panel restarted — token aktif sekarang"
    else
        echo "⚠ Panel gagal restart, cek: journalctl -u openclaw-panel -n 20"
    fi
else
    echo "ℹ Panel tidak jalan via systemd"
    echo "  Jalankan manual: PANEL_TOKEN=$NEW_TOKEN python3 /root/openclaw/panel/app.py"
fi

echo ""
echo "Token aktif : $NEW_TOKEN"
echo "Akses panel : http://$(hostname -I | awk '{print $1}'):7842"
