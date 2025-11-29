#!/bin/bash

# Common helper functions

# Ensure log directory exists
mkdir -p logs

# Default log file
LOG_FILE="logs/server_config.log"
# Default log level
LOG_LEVEL=${LOG_LEVEL:-"INFO"}

# Log level priority map
LOG_LEVEL_PRIORITY=("DEBUG" "INFO" "WARN" "ERROR")

# Resolve the priority index for a given level
get_log_priority() {
    local level=$1
    for i in "${!LOG_LEVEL_PRIORITY[@]}"; do
        if [ "${LOG_LEVEL_PRIORITY[$i]}" = "$level" ]; then
            echo $i
            return
        fi
    done
    echo 1  # default to INFO priority
}

# Log helper
log() {
    local level=$1
    local message=$2
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    local formatted="[$timestamp] [$level] $message"
    
    # Always write to log file
    echo "$formatted" >> "$LOG_FILE"
    
    # Emit to console when level meets threshold
    local current_priority=$(get_log_priority "$LOG_LEVEL")
    local message_priority=$(get_log_priority "$level")
    
    # Only print when message priority is >= configured level
    if [ $message_priority -ge $current_priority ]; then
        local color_prefix="" color_suffix=""
        if [ -t 1 ]; then
            case "$level" in
                "DEBUG") color_prefix="\033[34m" ;;
                "INFO") color_prefix="\033[32m" ;;
                "WARN") color_prefix="\033[33m" ;;
                "ERROR") color_prefix="\033[31m" ;;
            esac
            if [ -n "$color_prefix" ]; then
                color_suffix="\033[0m"
            fi
        fi
        if [ -n "$color_prefix" ]; then
            printf "%b%s%b\n" "$color_prefix" "$formatted" "$color_suffix"
        else
            echo "$formatted"
        fi
    fi
}

# Persist HTTP proxy information to the appropriate shell rc file for the user
set_http_proxy() {
    local proxy_value="$1"

    if [ -z "$proxy_value" ]; then
        log "ERROR" "set_http_proxy requires a proxy value"
        return 1
    fi

    local shell_name rc_file
    shell_name=$(basename "${SHELL:-/bin/bash}")

    case "$shell_name" in
        bash|sh)
            rc_file="$HOME/.bashrc"
            ;;
        zsh)
            rc_file="$HOME/.zshrc"
            ;;
        *)
            rc_file="$HOME/.profile"
            ;;
    esac

    if [ ! -e "$rc_file" ]; then
        if ! touch "$rc_file"; then
            log "ERROR" "Failed to create shell rc file $rc_file"
            return 1
        fi
    fi

    local block_start="# >>> TLNX HTTP proxy >>>"
    local block_end="# <<< TLNX HTTP proxy <<<"

    if grep -Fq "$block_start" "$rc_file" && grep -Fq "$block_end" "$rc_file"; then
        local tmp_file
        tmp_file=$(mktemp) || {
            log "ERROR" "Failed to create temporary file for proxy configuration"
            return 1
        }
        awk -v start="$block_start" -v end="$block_end" '
            $0 == start {skip=1; next}
            $0 == end {skip=0; next}
            skip == 0 {print}
        ' "$rc_file" > "$tmp_file"
        cat "$tmp_file" > "$rc_file"
        rm -f "$tmp_file"
    fi

    cat <<EOF >> "$rc_file"
$block_start
export http_proxy="$proxy_value"
export https_proxy="$proxy_value"
export HTTP_PROXY="$proxy_value"
export HTTPS_PROXY="$proxy_value"
$block_end
EOF

    export http_proxy="$proxy_value"
    export https_proxy="$proxy_value"
    export HTTP_PROXY="$proxy_value"
    export HTTPS_PROXY="$proxy_value"

    log "INFO" "HTTP proxy configuration saved to $rc_file"
    return 0
}
