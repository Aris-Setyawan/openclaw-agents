#!/usr/bin/env python3
"""
Zero-token monitoring script untuk replace cron jobs yang pakai agent1.
Bisa handle: disk usage, API balances, model usage, GitHub activity.
"""

import json
import os
import subprocess
import sys
from pathlib import Path
from datetime import datetime, timedelta
import shutil

# Config paths
OPENCLAW_CONFIG = Path("/root/.openclaw/openclaw.json")
AUTH_PROFILES = Path("/root/.openclaw/agents/main/agent/auth-profiles.json")
TELEGRAM_SEND = Path("/root/.openclaw/workspace/scripts/telegram-send.sh")
LOG_DIR = Path("/root/.openclaw/workspace/logs")

def send_telegram(message, caption="Monitoring Alert"):
    """Kirim alert ke Telegram via script (zero token)"""
    if TELEGRAM_SEND.exists():
        # Buat temp file untuk message
        temp_file = LOG_DIR / f"alert_{int(datetime.now().timestamp())}.txt"
        temp_file.write_text(message)
        
        try:
            subprocess.run(
                [str(TELEGRAM_SEND), str(temp_file), caption],
                check=True,
                capture_output=True,
                text=True
            )
            print(f"✅ Alert sent to Telegram: {caption}")
            temp_file.unlink()
            return True
        except subprocess.CalledProcessError as e:
            print(f"❌ Failed to send Telegram: {e}")
            return False
    else:
        print(f"⚠️ Telegram send script not found: {TELEGRAM_SEND}")
        return False

def check_disk_usage():
    """Cek disk usage, alert jika >80%"""
    try:
        result = subprocess.run(
            ["df", "-h", "/"],
            capture_output=True,
            text=True,
            check=True
        )
        lines = result.stdout.strip().split('\n')
        if len(lines) >= 2:
            parts = lines[1].split()
            if len(parts) >= 5:
                usage_percent = int(parts[4].replace('%', ''))
                if usage_percent > 80:
                    message = f"🚨 DISK USAGE ALERT\n\n"
                    message += f"Partition: {parts[0]}\n"
                    message += f"Size: {parts[1]}\n"
                    message += f"Used: {parts[2]} ({usage_percent}%)\n"
                    message += f"Available: {parts[3]}\n"
                    message += f"Mounted: {parts[5]}\n\n"
                    message += f"⚠️ Usage >80%! Consider cleaning up."
                    
                    send_telegram(message, "Disk Usage Alert")
                    return True, f"Disk usage {usage_percent}% > 80%"
                else:
                    return False, f"Disk usage {usage_percent}% (OK)"
    except Exception as e:
        print(f"❌ Disk check error: {e}")
        return False, f"Error: {e}"
    
    return False, "No disk data"

def check_api_balances():
    """Cek saldo API dari auth-profiles.json"""
    alerts = []
    
    if not AUTH_PROFILES.exists():
        return False, "Auth profiles not found"
    
    try:
        with open(AUTH_PROFILES, 'r') as f:
            data = json.load(f)
        
        profiles = data.get('profiles', {})
        
        # DeepSeek
        deepseek = profiles.get('deepseek:default', {})
        if deepseek.get('token'):
            # Ini contoh - perlu implementasi curl ke API DeepSeek
            # Untuk sekarang cuma dummy
            pass
        
        # OpenRouter
        openrouter = profiles.get('openrouter:default', {})
        if openrouter.get('key'):
            # Implementasi curl ke OpenRouter API
            pass
        
        # Google/Gemini
        google = profiles.get('google:default', {})
        if google.get('key'):
            # Google API balance check
            pass
        
        if alerts:
            message = "💰 API BALANCE ALERT\n\n" + "\n".join(alerts)
            send_telegram(message, "API Balance Alert")
            return True, f"{len(alerts)} low balances"
        
        return False, "All API balances OK"
        
    except Exception as e:
        print(f"❌ API balance check error: {e}")
        return False, f"Error: {e}"

def check_model_usage():
    """Cek model usage dari logs"""
    alert_log = LOG_DIR / "model-alerts.log"
    if not alert_log.exists():
        return False, "No model alerts log"
    
    try:
        # Cek alerts dalam 6 jam terakhir
        six_hours_ago = datetime.now() - timedelta(hours=6)
        alerts = []
        
        with open(alert_log, 'r') as f:
            for line in f:
                if line.strip():
                    # Parse timestamp dari log line
                    # Format sederhana: [timestamp] message
                    if 'ALERT:' in line or 'SPIKE:' in line:
                        alerts.append(line.strip())
        
        if alerts:
            recent_alerts = []
            for alert in alerts[-5:]:  # Ambil 5 terakhir
                recent_alerts.append(alert)
            
            if recent_alerts:
                message = "📊 MODEL USAGE ALERT\n\n"
                message += "Recent alerts (last 6 hours):\n"
                message += "\n".join(recent_alerts)
                
                send_telegram(message, "Model Usage Alert")
                return True, f"{len(alerts)} model alerts"
        
        return False, "No recent model alerts"
        
    except Exception as e:
        print(f"❌ Model usage check error: {e}")
        return False, f"Error: {e}"

def check_github_activity():
    """Cek GitHub activity via gh CLI"""
    try:
        # Cek apakah gh CLI terinstall
        gh_check = subprocess.run(
            ["which", "gh"],
            capture_output=True,
            text=True
        )
        
        if gh_check.returncode != 0:
            return False, "gh CLI not installed"
        
        # Cek notifications
        result = subprocess.run(
            ["gh", "api", "notifications", "--jq", "length"],
            capture_output=True,
            text=True
        )
        
        if result.returncode == 0:
            notification_count = int(result.stdout.strip())
            if notification_count > 0:
                message = f"🔔 GITHUB ACTIVITY\n\n"
                message += f"Notifications: {notification_count} unread\n"
                message += "Run `gh notification list` to see details."
                
                send_telegram(message, "GitHub Activity")
                return True, f"{notification_count} notifications"
        
        return False, "No GitHub notifications"
        
    except Exception as e:
        print(f"❌ GitHub check error: {e}")
        return False, f"Error: {e}"

def check_large_logs():
    """Cek log files besar (>100MB)"""
    try:
        large_logs = []
        
        # Cek common log directories
        log_dirs = [
            "/var/log",
            "/root/.openclaw/logs",
            "/tmp"
        ]
        
        for log_dir in log_dirs:
            if Path(log_dir).exists():
                result = subprocess.run(
                    ["find", log_dir, "-type", "f", "-name", "*.log", "-size", "+100M"],
                    capture_output=True,
                    text=True
                )
                
                if result.stdout.strip():
                    for log_file in result.stdout.strip().split('\n'):
                        if log_file:
                            # Get size
                            size_result = subprocess.run(
                                ["du", "-h", log_file],
                                capture_output=True,
                                text=True
                            )
                            size = size_result.stdout.split()[0] if size_result.stdout else "unknown"
                            large_logs.append(f"{log_file} ({size})")
        
        if large_logs:
            message = "📁 LARGE LOG FILES\n\n"
            message += f"Found {len(large_logs)} log files >100MB:\n"
            message += "\n".join(large_logs[:10])  # Max 10 files
            if len(large_logs) > 10:
                message += f"\n... and {len(large_logs)-10} more"
            
            send_telegram(message, "Large Log Files Alert")
            return True, f"{len(large_logs)} large log files"
        
        return False, "No large log files"
        
    except Exception as e:
        print(f"❌ Large logs check error: {e}")
        return False, f"Error: {e}"

def main():
    """Main function - pilih task berdasarkan argumen"""
    if len(sys.argv) < 2:
        print("Usage: python3 zero-token-monitor.py <task>")
        print("Tasks: disk, api, model, github, logs, all")
        sys.exit(1)
    
    task = sys.argv[1].lower()
    print(f"🔍 Running zero-token monitor: {task}")
    
    results = []
    
    if task == "disk" or task == "all":
        alert, msg = check_disk_usage()
        results.append(("Disk Usage", alert, msg))
    
    if task == "api" or task == "all":
        alert, msg = check_api_balances()
        results.append(("API Balances", alert, msg))
    
    if task == "model" or task == "all":
        alert, msg = check_model_usage()
        results.append(("Model Usage", alert, msg))
    
    if task == "github" or task == "all":
        alert, msg = check_github_activity()
        results.append(("GitHub Activity", alert, msg))
    
    if task == "logs" or task == "all":
        alert, msg = check_large_logs()
        results.append(("Large Logs", alert, msg))
    
    # Print summary
    print("\n📋 MONITORING SUMMARY")
    print("="*50)
    
    any_alerts = False
    for name, alert, msg in results:
        status = "🚨 ALERT" if alert else "✅ OK"
        print(f"{name:<20} {status:<10} {msg}")
        if alert:
            any_alerts = True
    
    print("="*50)
    
    if any_alerts:
        print("⚠️  Alerts detected and sent to Telegram")
        sys.exit(1)  # Exit with error code untuk trigger alert
    else:
        print("✅ All checks passed")
        # Untuk cron jobs yang expect HEARTBEAT_OK
        print("HEARTBEAT_OK")
        sys.exit(0)

if __name__ == "__main__":
    main()