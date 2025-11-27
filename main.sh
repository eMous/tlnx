#!/bin/bash

# Automated server configuration tool - main entrypoint

# Load library files
source "lib/common.sh"
source "lib/remote.sh"
source "lib/config.sh"
source "lib/module.sh"

# Display usage information
display_usage() {
    echo "tlnx automated server configuration usage"
    # Resolve current hostname
    local current_hostname=$(hostname)
    
    # Identify remote mode through SSH_CLIENT_HOST
    if [ -n "${SSH_CLIENT_HOST:-}" ]; then
        echo -e "\033[31m[Mode: Remote] Running on server ${current_hostname}, session initiated from ${SSH_CLIENT_HOST}\033[0m"
    else
        echo -e "\033[31m[Mode: Local] Running on local host ${current_hostname}\033[0m"
    fi
    echo ""
    echo "Usage:"
    echo "  ./main.sh [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help           Show this help"
    echo "  -l, --log-level LEVEL  Set log level (DEBUG, INFO, WARN, ERROR)"
    echo "  -t, --test           Run in test mode"
    echo "  -f, --force          Force installation even if a module reports itself as installed"
    echo "  --modules MODULES    Comma-separated module list to run"
    echo "  --select-modules     Show available module scripts and choose by number"
    echo "  -d, --decrypt        Decrypt config/enc.conf.enc into config/enc.conf"
    echo "  -c, --encrypt        Encrypt config/enc.conf into config/enc.conf.enc"
    echo ""
    echo "Examples:"
    echo "  ./main.sh -l INFO"
    echo "  ./main.sh --modules docker,zsh"
    echo "  ./main.sh -d"
    echo "  ./main.sh -c"
}

# Gather available module scripts from the modules directory
get_available_modules() {
    shopt -s nullglob
    local module_file
    local module_list=()
    for module_file in modules/*.sh; do
        module_list+=("$(basename "$module_file" .sh)")
    done
    shopt -u nullglob

    if [ ${#module_list[@]} -eq 0 ]; then
        return 0
    fi

    printf '%s\n' "${module_list[@]}"
}

# Display module names with numeric indices for interactive selection
print_module_menu() {
    local modules=("$@")
    local idx=1
    for module in "${modules[@]}"; do
        printf "  %d) %s\n" "$idx" "$module"
        idx=$((idx+1))
    done
}

# Buffer for interactive selection results
PROMPT_MODULE_SELECTION_RESULT=""

# Prompt the user to select modules by number and return a comma-separated string
prompt_module_selection() {
    local modules=("$@")
    if [ ${#modules[@]} -eq 0 ]; then
        return 1
    fi

    PROMPT_MODULE_SELECTION_RESULT=""
    
    echo "Available modules:"
    print_module_menu "${modules[@]}"

    local selection
    read -rp "Select modules by number (comma-separated, e.g., 1,3): " selection
    local cleaned
    cleaned=$(echo "$selection" | tr -c '0-9,' ' ')

    IFS=$' ,\t\n' read -ra tokens <<< "$cleaned"
    local selected=()
    for token in "${tokens[@]}"; do
        if [ -z "$token" ]; then
            continue
        fi
        if [[ ! "$token" =~ ^[0-9]+$ ]]; then
            continue
        fi
        local index=$((token - 1))
        if [ "$index" -lt 0 ] || [ "$index" -ge "${#modules[@]}" ]; then
            log "WARNING" "Module number out of range: $token"
            continue
        fi
        local module="${modules[$index]}"
        if [[ ! " ${selected[*]} " =~ " ${module} " ]]; then
            selected+=("$module")
        fi
    done

    if [ ${#selected[@]} -eq 0 ]; then
        return 1
    fi

    local IFS=','
    PROMPT_MODULE_SELECTION_RESULT="${selected[*]}"
    return 0
}

# Main function
main() {
    # Initialize defaults
    local LOG_LEVEL="INFO"
    local TEST_MODE="false"
    local CUSTOM_MODULES=""
    local DECRYPT_MODE="false"
    local ENCRYPT_MODE="false"
    local INTERACTIVE_SELECT="false"
    
    # Parse CLI arguments
    local i=1
    local FORCE_MODE="false"
    while [ $i -le $# ]; do
        local arg=${!i}
        if [ "$arg" = "-l" ] || [ "$arg" = "--log-level" ]; then
            local next_i=$((i+1))
            LOG_LEVEL="${!next_i}"
            i=$((i+2))
        elif [ "$arg" = "-t" ] || [ "$arg" = "--test" ]; then
            TEST_MODE="true"
            i=$((i+1))
        elif [ "$arg" = "--modules" ]; then
            local next_i=$((i+1))
            CUSTOM_MODULES="${!next_i}"
            i=$((i+2))
        elif [ "$arg" = "--select-modules" ]; then
            INTERACTIVE_SELECT="true"
            i=$((i+1))
        elif [ "$arg" = "-h" ] || [ "$arg" = "--help" ]; then
            display_usage
            exit 0
        elif [ "$arg" = "-d" ] || [ "$arg" = "--decrypt" ]; then
            DECRYPT_MODE="true"
            i=$((i+1))
        elif [ "$arg" = "-c" ] || [ "$arg" = "--encrypt" ]; then
            ENCRYPT_MODE="true"
            i=$((i+1))
        elif [ "$arg" = "-f" ] || [ "$arg" = "--force" ]; then
            FORCE_MODE="true"
            i=$((i+1))
        else
            echo "Error: unknown argument $arg" >&2
            display_usage
            exit 1
        fi
    done
    
    # Handle decrypt/encrypt only modes
    if [ "$DECRYPT_MODE" = "true" ]; then
        echo "Running decrypt option..."
        bash "scripts/decrypt.sh" "config/enc.conf.enc" "config/enc.conf"
        if [ $? -eq 0 ]; then
            echo "Decryption succeeded: config/enc.conf.enc -> config/enc.conf"
        else
            echo "Decryption failed"
            exit 1
        fi
        exit 0
    fi
    
    if [ "$ENCRYPT_MODE" = "true" ]; then
        echo "Running encrypt option..."
        bash "scripts/encrypt.sh" "config/enc.conf" "config/enc.conf.enc"
        if [ $? -eq 0 ]; then
            echo "Encryption succeeded: config/enc.conf -> config/enc.conf.enc"
        else
            echo "Encryption failed"
            exit 1
        fi
        exit 0
    fi
    
    # Reload config after decrypt/encrypt
    load_config
    
    if [ "$INTERACTIVE_SELECT" = "true" ]; then
        local -a AVAILABLE_MODULES
        if command -v mapfile >/dev/null 2>&1; then
            mapfile -t AVAILABLE_MODULES < <(get_available_modules)
        else
            while IFS= read -r module; do
                AVAILABLE_MODULES+=("$module")
            done < <(get_available_modules)
        fi
        if [ ${#AVAILABLE_MODULES[@]} -eq 0 ]; then
            log "WARNING" "No module scripts detected for interactive selection"
        else
            if prompt_module_selection "${AVAILABLE_MODULES[@]}"; then
                CUSTOM_MODULES="$PROMPT_MODULE_SELECTION_RESULT"
                log "INFO" "Interactive module selection: ${CUSTOM_MODULES}"
            else
                log "WARNING" "No modules were selected interactively; using configured module list"
            fi
        fi
    fi

    log "INFO" "Starting automated server configuration"
    
    # Test mode: print configuration values and exit
    if [ "$TEST_MODE" = "true" ]; then
        log "INFO" "Test mode: only load configuration without running modules"
        
        log "INFO" "===== Non-empty configuration values ====="
        
        local template_file="config/default.conf.template"
        local default_file="config/default.conf"
        local config_vars=()
        
        for file in "$template_file" "$default_file"; do
            while IFS='=' read -r var_name _; do
                if [[ "$var_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
                    local exists=false
                    for existing_var in "${config_vars[@]}"; do
                        if [ "$existing_var" = "$var_name" ]; then
                            exists=true
                            break
                        fi
                    done
                    if [ "$exists" = false ]; then
                        config_vars+=("$var_name")
                    fi
                fi
            done < <(grep -E '^[a-zA-Z_][a-zA-Z0-9_]*=' "$file")
        done
        
        for var in "${config_vars[@]}"; do
            if [ -z "${!var+x}" ]; then
                continue
            fi
            
            if declare -p "$var" 2>/dev/null | grep -q 'declare -a'; then
                declare -n arr="$var"
                local array_values=()
                for item in "${arr[@]}"; do
                    array_values+=("$item")
                done
                if [ ${#array_values[@]} -gt 0 ]; then
                    log "INFO" "$var = (${array_values[*]})"
                fi
                unset -n arr
            else
                local value="${!var}"
                if [ -n "$value" ] && [ "$value" != "!!!!!!!ENCRYPTED!!!!!!!" ]; then
                    log "INFO" "$var = $value"
                fi
            fi
        done
        
        log "INFO" "TARGET_HOST = $TARGET_HOST"
        log "INFO" "TARGET_USER = $TARGET_USER"
        log "INFO" "TARGET_PORT = $TARGET_PORT"
        log "INFO" "TARGET_PASSWORD = $TARGET_PASSWORD"
        
        log "INFO" "===== End of configuration values ====="
        log "INFO" "Configuration loaded; test mode finished"
        exit 0
    fi
    
    # Environment detection - determine execution context
    if [ "${IS_EXECUTION_ENVIRONMENT:-false}" != "true" ]; then
        # Not the execution environment; transfer to target host
        if [ -z "$TARGET_HOST" ] || [ -z "$TARGET_USER" ]; then
            log "ERROR" "TARGET_HOST and TARGET_USER must be set when not running in the execution environment"
            exit 1
        fi
        # Start remote transfer immediately
        log "INFO" "Detected non-execution environment; transferring to remote host"
        remote_execution "$TARGET_HOST" "$TARGET_USER" "$TARGET_PORT"
        exit $?
    fi
    
    detect_distro
    
    # Determine which modules to run
    local MODULES_TO_EXECUTE=()
    
    # Use custom module list when provided
    if [ -n "$CUSTOM_MODULES" ]; then
        IFS=',' read -r -a MODULES_TO_EXECUTE <<< "$CUSTOM_MODULES"
        log "INFO" "Using custom module list: ${MODULES_TO_EXECUTE[*]}"
    # Otherwise read from config
    elif [ -n "${CONFIG_MODULES[*]}" ]; then
        MODULES_TO_EXECUTE=("${CONFIG_MODULES[@]}")
        log "INFO" "Using modules from config: ${MODULES_TO_EXECUTE[*]}"
    # Default to empty if nothing specified
    else
        MODULES_TO_EXECUTE=()
        log "INFO" "No module list configured; defaulting to empty list"
    fi
    
    # Handle required modules
    if [ -n "${CONFIG_REQUIRED_MODULES[*]}" ]; then
        log "INFO" "Required modules: ${CONFIG_REQUIRED_MODULES[*]}"
        
        # Build final ordered list while preventing duplicates
        local FINAL_MODULES=()
        
        # Add required modules first
        for req_module in "${CONFIG_REQUIRED_MODULES[@]}"; do
            if [[ ! "${FINAL_MODULES[*]}" =~ "$req_module" ]]; then
                FINAL_MODULES+=("$req_module")
            fi
        done
        
        # Append optional modules while avoiding duplicates
        for module in "${MODULES_TO_EXECUTE[@]}"; do
            if [[ ! "${FINAL_MODULES[*]}" =~ "$module" ]]; then
                FINAL_MODULES+=("$module")
            fi
        done
        
        # Update the final sequence
        MODULES_TO_EXECUTE=("${FINAL_MODULES[@]}")
        log "INFO" "Final module order: ${MODULES_TO_EXECUTE[*]}"
    fi
    
    # Exit if nothing to run
    if [ ${#MODULES_TO_EXECUTE[@]} -eq 0 ]; then
        log "INFO" "No modules to execute"
        exit 0
    fi
    
    # Execute modules
    for module in "${MODULES_TO_EXECUTE[@]}"; do
        execute_module "$module" "$FORCE_MODE"
    done
    
    log "INFO" "Automated server configuration completed"
}

# Invoke entrypoint
main "$@"
