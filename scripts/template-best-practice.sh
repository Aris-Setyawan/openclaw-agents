#!/bin/bash
# Template: Best Practice Shell Script untuk OpenClaw
# Gunakan template ini untuk script baru atau refactor script lama

set -euo pipefail
IFS=$'\n\t'

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# CONFIGURATION & CONSTANTS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Default values dengan environment variable override
: "${OPENCLAW_DIR:=/root/.openclaw}"
: "${OPENCLAW_WORKSPACE:=$OPENCLAW_DIR/workspace}"
: "${SCRIPT_NAME:=$(basename "$0")}"
: "${LOG_LEVEL:=INFO}"  # DEBUG, INFO, WARN, ERROR

# Safe temporary files (auto-cleanup on exit)
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT INT TERM

# Log file
LOG_FILE="$TEMP_DIR/${SCRIPT_NAME}.log"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# LOGGING FUNCTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Check log level
    case "$LOG_LEVEL" in
        DEBUG) ;;
        INFO) [[ "$level" == "DEBUG" ]] && return ;;
        WARN) [[ "$level" == "DEBUG" || "$level" == "INFO" ]] && return ;;
        ERROR) [[ "$level" != "ERROR" ]] && return ;;
    esac
    
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

log_debug() { log "DEBUG" "$1"; }
log_info()  { log "INFO" "$1"; }
log_warn()  { log "WARN" "$1"; }
log_error() { log "ERROR" "$1"; }

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# API KEY MANAGEMENT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Cari API key dari semua agent (prioritaskan environment variable)
get_api_key() {
    local provider="$1"
    local key_type="${2:-key}"  # 'key' atau 'token'
    
    # 1. Coba dari environment variable dulu (paling aman)
    local env_var="${provider^^}_API_KEY"
    if [ -n "${!env_var:-}" ]; then
        echo "${!env_var}"
        log_debug "Got $provider API key from environment variable"
        return 0
    fi
    
    # 2. Cari dari semua auth-profiles.json
    for auth_file in "$OPENCLAW_DIR"/agents/*/agent/auth-profiles.json; do
        if [ -f "$auth_file" ]; then
            local key=$(python3 -c "
import json, sys
try:
    with open('$auth_file') as f:
        d = json.load(f)
    profiles = d.get('profiles', {})
    provider_profile = profiles.get('${provider}:default', {})
    key = provider_profile.get('$key_type') or provider_profile.get('token')
    if key:
        print(key)
except Exception as e:
    sys.stderr.write(f'Error reading {auth_file}: {e}\\n')
" 2>/dev/null)
            
            if [ -n "$key" ]; then
                echo "$key"
                log_debug "Got $provider API key from $auth_file"
                return 0
            fi
        fi
    done
    
    log_error "API key for $provider not found"
    return 1
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# VALIDATION FUNCTIONS
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

validate_file() {
    local file="$1"
    local description="$2"
    
    if [ ! -f "$file" ]; then
        log_error "$description not found: $file"
        return 1
    fi
    
    if [ ! -r "$file" ]; then
        log_error "$description not readable: $file"
        return 1
    fi
    
    log_debug "Validated $description: $file"
    return 0
}

validate_directory() {
    local dir="$1"
    local description="$2"
    
    if [ ! -d "$dir" ]; then
        log_error "$description not found: $dir"
        return 1
    fi
    
    if [ ! -w "$dir" ]; then
        log_error "$description not writable: $dir"
        return 1
    fi
    
    log_debug "Validated $description: $dir"
    return 0
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# SAFE CURL WRAPPER
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

safe_curl() {
    local url="$1"
    shift
    local response_file="$TEMP_DIR/curl_response_$$.json"
    
    # Execute curl dengan timeout dan fail on HTTP errors
    if curl -f -s -S --max-time 30 "$@" "$url" > "$response_file"; then
        cat "$response_file"
        return 0
    else
        local exit_code=$?
        log_error "CURL failed with exit code $exit_code for URL: $url"
        if [ -f "$response_file" ] && [ -s "$response_file" ]; then
            log_error "Response: $(cat "$response_file")"
        fi
        return $exit_code
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# USAGE & HELP
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

show_usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS] <required_arg>

Description:
  Template script dengan best practices untuk OpenClaw.

Options:
  -h, --help          Show this help message
  -v, --verbose       Enable verbose logging
  -q, --quiet         Only show errors
  -d, --debug         Enable debug logging
  --config FILE       Use custom config file

Examples:
  $SCRIPT_NAME --verbose action_name
  $SCRIPT_NAME --debug --config /path/to/config.json

EOF
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ARGUMENT PARSING
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--verbose)
                LOG_LEVEL="DEBUG"
                shift
                ;;
            -q|--quiet)
                LOG_LEVEL="ERROR"
                shift
                ;;
            -d|--debug)
                LOG_LEVEL="DEBUG"
                set -x  # Enable trace
                shift
                ;;
            --config)
                if [ -z "${2:-}" ]; then
                    log_error "Missing value for --config"
                    exit 1
                fi
                CONFIG_FILE="$2"
                shift 2
                ;;
            --)
                shift
                break
                ;;
            -*)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                POSITIONAL_ARGS+=("$1")
                shift
                ;;
        esac
    done
    
    # Handle positional arguments
    if [ ${#POSITIONAL_ARGS[@]} -eq 0 ]; then
        log_error "Missing required argument"
        show_usage
        exit 1
    fi
    
    MAIN_ARG="${POSITIONAL_ARGS[0]}"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# MAIN EXECUTION
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

main() {
    log_info "Starting $SCRIPT_NAME"
    
    # Parse arguments
    POSITIONAL_ARGS=()
    parse_arguments "$@"
    
    # Validate environment
    validate_directory "$OPENCLAW_DIR" "OpenClaw directory"
    validate_directory "$OPENCLAW_WORKSPACE" "OpenClaw workspace"
    
    # Contoh: Get API key
    log_info "Fetching API keys..."
    GEMINI_KEY=$(get_api_key "google") || exit 1
    DEEPSEEK_KEY=$(get_api_key "deepseek" "token") || exit 1
    
    # Mask keys in logs (hanya tampilkan 5 karakter pertama)
    log_debug "Gemini key: ${GEMINI_KEY:0:5}..."
    log_debug "DeepSeek key: ${DEEPSEEK_KEY:0:5}..."
    
    # Contoh: Safe API call
    log_info "Making API request..."
    RESPONSE=$(safe_curl "https://api.deepseek.com/user/balance" \
        -H "Authorization: Bearer $DEEPSEEK_KEY") || {
        log_error "Failed to get DeepSeek balance"
        exit 1
    }
    
    # Process response
    BALANCE=$(echo "$RESPONSE" | jq -r '.balance_infos[0].total_balance // "unknown"' 2>/dev/null || echo "error")
    log_info "DeepSeek balance: \$$BALANCE"
    
    log_info "$SCRIPT_NAME completed successfully"
    return 0
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ENTRY POINT
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Only run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi