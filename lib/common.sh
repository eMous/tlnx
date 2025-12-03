#!/bin/bash

# Common helper functions

# Ensure log directory exists
mkdir -p "$PROJECT_DIR/logs"
# Default log file
LOG_FILE="${PROJECT_DIR:+${PROJECT_DIR}/}logs/server_config.log"
# Default log level
LOG_LEVEL=${LOG_LEVEL:-"INFO"}

# Log level priority map
LOG_LEVEL_PRIORITY=("VERBOSE" "DEBUG" "INFO" "WARN" "ERROR")

# Resolve the priority index for a given level
get_log_priority() {
    local level=$1
    for i in "${!LOG_LEVEL_PRIORITY[@]}"; do
        if [ "${LOG_LEVEL_PRIORITY[$i]}" = "$level" ]; then
            echo $i
            return
        fi
    done
}

# Log helper
log() {
    local level=$1
    local message=$2
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    local formatted="[$timestamp] [$level] $message"

    # Always write to log file
    echo "$formatted" >>$LOG_FILE
    # Emit to console when level meets threshold
    local current_priority=$(get_log_priority "$LOG_LEVEL")
    local message_priority=$(get_log_priority "$level")

    # Only print when message priority is >= configured level
    if [ $message_priority -ge $current_priority ]; then
        local color_prefix="" color_suffix=""
        if [ -t 1 ] || [ -t 0 ]; then
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
    bash | sh)
        rc_file="$HOME/.bashrc"
        ;;
    zsh)
        rc_file="$HOME/.zshrc"
        ;;
    *)
        log "WARN" "Unsupported shell $shell_name; cannot set HTTP proxy"
        return 1
        ;;
    esac
    rc_file="${2:-${rc_file}}"
    if [ ! -e "$rc_file" ]; then
        if ! touch "$rc_file"; then
            log "ERROR" "Failed to create shell rc file $rc_file"
            return 1
        fi
    fi

    local proxy_block
    proxy_block=$(
        cat <<EOF
export http_proxy="$proxy_value"
export https_proxy="$proxy_value"
export HTTP_PROXY="$proxy_value"
export HTTPS_PROXY="$proxy_value"
EOF
    )
    source "$PROJECT_DIR/lib/shell.sh"
    append_shell_rc_block "$proxy_block" "$rc_file" || return 1

    export http_proxy="$proxy_value"
    export https_proxy="$proxy_value"
    export HTTP_PROXY="$proxy_value"
    export HTTPS_PROXY="$proxy_value"

    log "INFO" "HTTP proxy configuration saved to $rc_file"
    return 0
}

# Helper to run sudo with a provided password
_tlnx_run_sudo_with_password() {
    local password="$1"
    shift || true
    if [ -z "$password" ]; then
        return 1
    fi

    log "DEBUG" "Running sudo command with provided password: sudo $*"
    if printf '%s\n' "$password" | command sudo -S -p '' "$@" 2>&1 | tee -a "$LOG_FILE"; then
        return 0
    fi

    return $?
}

# Wrapper to run sudo commands with password fallbacks
sudo() {
    local status
    if [ -n "${TLNX_PASSWD:-}" ]; then
        log "DEBUG" "Attempting sudo with cached TLNX_PASSWD"
        if _tlnx_run_sudo_with_password "$TLNX_PASSWD" "$@"; then
            log "DEBUG" "sudo succeeded using cached TLNX_PASSWD"
            return 0
        else
            status=$?
            log "WARN" "sudo authentication with TLNX_PASSWD failed (exit $status)"
        fi
    fi
    if [ -n "${LOCAL_USER_PASSWD:-}" ]; then
        log "DEBUG" "Attempting sudo with LOCAL_USER_PASSWD"
        if _tlnx_run_sudo_with_password "$LOCAL_USER_PASSWD" "$@"; then
            TLNX_PASSWD="$LOCAL_USER_PASSWD"
            log "DEBUG" "sudo succeeded using LOCAL_USER_PASSWD; cached in TLNX_PASSWD"
            return 0
        else
            status=$?
            log "WARN" "sudo authentication with LOCAL_USER_PASSWD failed (exit $status)"
        fi
    fi

    if [ -n "${REMOTE_ENC_PASSWORD:-}" ]; then
        log "DEBUG" "Attempting sudo with REMOTE_ENC_PASSWORD"
        if _tlnx_run_sudo_with_password "$REMOTE_ENC_PASSWORD" "$@"; then
            TLNX_PASSWD="$REMOTE_ENC_PASSWORD"
            log "DEBUG" "sudo succeeded using REMOTE_ENC_PASSWORD; cached in TLNX_PASSWD"
            return 0
        else
            status=$?
            log "WARN" "sudo authentication with REMOTE_ENC_PASSWORD failed (exit $status)"
        fi
    fi

    log "INFO" "All stored sudo passwords failed; prompting for input"
    command sudo "$@"
    return $?
}
