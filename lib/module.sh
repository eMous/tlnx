#!/bin/bash

# Module execution helpers

# Usage helper (unused but kept for reference)
display_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -l, --log-level <level>   Set log level (DEBUG, INFO, WARNING, ERROR); default INFO"
    echo "  -t, --test               Test mode: load config without running modules"
    echo "  --modules <list>        Comma-separated modules, e.g., --modules docker,zsh"
    echo "  -h, --help               Show help"
    echo ""
    echo "Examples:"
    echo "  $0 -l DEBUG"
    echo "  $0 -t  # test configuration loading"
    echo "  $0 --modules docker,zsh  # run only docker and zsh"
}

# Execute a module
execute_module() {
    local module=$1
    local force=${2:-"false"}
    log "INFO" "Executing module: $module"
    
    if [ -f "modules/$module.sh" ]; then
        source "modules/$module.sh"
        local need_install=true
        
        if [ "$force" != "true" ]; then
            local check_func="_${module}_check_installed"
            if command -v "$check_func" &> /dev/null; then
                if "$check_func"; then
                    log "INFO" "Module $module already installed; skipping installation"
                    need_install=false
                else
                    log "INFO" "Module $module not installed; starting installation"
                fi
            else
                log "WARNING" "Module $module does not provide $check_func"
                exit 1
            fi
        else
            log "INFO" "Force re-installation for module $module"
        fi
        
        if [ "$need_install" = "true" ]; then
            local install_func="_${module}_install"
            if command -v "$install_func" &> /dev/null; then
                "$install_func"
                if [ $? -ne 0 ]; then
                    log "ERROR" "Module $module failed to run $install_func"
                    return 1
                fi
            else
                log "WARNING" "Module $module is missing ${install_func}; skipping installation"
            fi
        fi
        
        log "INFO" "Module $module completed"
    else
        log "WARNING" "Module script missing: modules/$module.sh; skipping"
        return 1
    fi
}
