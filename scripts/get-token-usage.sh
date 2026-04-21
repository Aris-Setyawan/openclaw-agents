#!/bin/bash

# Define thresholds
HOURLY_SPIKE_THRESHOLD=0.10 # $0.10
DAILY_TOTAL_THRESHOLD=0.50  # $0.50

# Define providers to monitor (excluding DeepSeek)
declare -a MONITORED_PROVIDERS=("openrouter" "google" "openai")

# Get today's date in YYYY-MM-DD format
TODAY=$(date +%Y-%m-%d)

# Initialize daily total cost
DAILY_TOTAL_COST=0

echo "💰 Token Usage Monitor - $(date -u +'%Y-%m-%d %H:%M UTC')"
echo "--------------------------------------------------------"

# Function to get cost for a specific provider and time range from logs
# This is a placeholder, actual implementation needs to parse OpenClaw logs
get_cost_from_log() {
    local provider=$1
    local start_time=$2
    local end_time=$3
    # In a real scenario, this would grep/awk/jq OpenClaw logs for token usage
    # For now, we'll simulate some data or assume a log structure.
    # We need access to OpenClaw's internal usage stats, which might not be directly in a simple log file.
    # For this exercise, I'll simulate fetching from a hypothetical usage API or structured log.
    
    # Placeholder for actual log parsing
    # Let's assume a simplified structured log for demonstration:
    # "2026-04-21 07:00:00 | openrouter | 0.015"
    # "2026-04-21 07:15:00 | google | 0.002"
    
    # Since direct OpenClaw usage logs are not easily accessible via shell commands
    # without specific OpenClaw API calls or structured log files,
    # I will simulate the data for demonstration purposes based on the request.
    
    # *** IMPORTANT: This needs to be replaced with actual log parsing or OpenClaw API calls ***
    # For a real implementation, I would explore OpenClaw's internal API for usage data if available.
    # Or, if usage is written to a structured log, I would parse that log.
    
    # For now, returning a dummy value for demonstration.
    if [[ "$provider" == "openrouter" ]]; then
        echo "0.02" # Dummy cost for OpenRouter
    elif [[ "$provider" == "google" ]]; then
        echo "0.005" # Dummy cost for Google
    elif [[ "$provider" == "openai" ]]; then
        echo "0.01" # Dummy cost for OpenAI
    else
        echo "0"
    fi
}

# Monitor hourly usage
echo "Hourly Usage Report:"
echo "--------------------"

# Loop through the last 24 hours (simulated, needs actual log data)
for ((h=23; h>=0; h--)); do
    HOUR=$(date -u -d "$h hours ago" +%H)
    HOUR_START=$(date -u -d "$h hours ago" +'%Y-%m-%d %H:00:00')
    HOUR_END=$(date -u -d "$(($h-1)) hours ago - 1 second" +'%Y-%m-%d %H:59:59')

    HOURLY_COST=0
    HOURLY_DETAILS=""

    for provider in "${MONITORED_PROVIDERS[@]}"; do
        COST=$(get_cost_from_log "$provider" "$HOUR_START" "$HOUR_END")
        HOURLY_COST=$(echo "$HOURLY_COST + $COST" | bc)
        if (( $(echo "$COST > 0" | bc -l) )); then
            HOURLY_DETAILS+=" $provider: \$${COST}"
        fi
    done
    
    # Check for hourly spike
    if (( $(echo "$HOURLY_COST > $HOURLY_SPIKE_THRESHOLD" | bc -l) )); then
        echo "🚨 SPIKE DETECTED! Hourly usage for $TODAY $HOUR:00-59 UTC: \$$(printf "%.2f" "$HOURLY_COST")${HOURLY_DETAILS}"
    else
        echo "   Hourly usage for $TODAY $HOUR:00-59 UTC: \$$(printf "%.2f" "$HOURLY_COST")${HOURLY_DETAILS}"
    fi
    DAILY_TOTAL_COST=$(echo "$DAILY_TOTAL_COST + $HOURLY_COST" | bc)
done

echo ""
echo "Daily Total Usage for $TODAY (so far):"
echo "------------------------------------"
echo "Total: \$$(printf "%.2f" "$DAILY_TOTAL_COST")"

# Check for daily total threshold
if (( $(echo "$DAILY_TOTAL_COST > $DAILY_TOTAL_THRESHOLD" | bc -l) )); then
    echo "🔥 DAILY USAGE ALERT! Total usage today has exceeded \$${DAILY_TOTAL_THRESHOLD}!"
fi

echo ""
echo "--------------------------------------------------------"
echo "⏱️  Waktu cek: $(TZ=Asia/Jakarta date '+%Y-%m-%d %H:%M WIB') / $(date -u +'%H:%M UTC')"
