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
    
    # Always write to log file
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    # Emit to console when level meets threshold
    local current_priority=$(get_log_priority "$LOG_LEVEL")
    local message_priority=$(get_log_priority "$level")
    
    # Only print when message priority is >= configured level
    if [ $message_priority -ge $current_priority ]; then
        echo "[$timestamp] [$level] $message"
    fi
}
