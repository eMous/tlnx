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

	if [ -f "$PROJECT_DIR/modules/$module.sh" ]; then
		source "$PROJECT_DIR/modules/$module.sh"
		local need_install=true

		if [ "$force" != "true" ]; then
			local check_func="_${module}_check_installed"
			if command -v "$check_func" &>/dev/null; then
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
			if command -v "$install_func" &>/dev/null; then
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

mark_older_than(){
    local mark=$1;
    local timestamp=$2;
    local mark_file="$PROJECT_DIR/run/marks"

	# if mark file doesn't exist, consider it older
	if [ ! -f "$mark_file" ]; then
		log "WARN" "Mark file $mark_file does not exist; considered older"
		touch "$mark_file" 
		return 0
	fi

	# if mark doesn't exist in mark file, consider it older
	if grep -Fq "^${mark} " "$mark_file"; then
		log "DEBUG" "Mark $mark found in $mark_file"
	else
		log "WARN" "Mark $mark not found in $mark_file; considered older"
		return 0
	fi

    # get the timestamp of the mark in mark_file
    local mark_timestamp
    mark_timestamp=$(grep -F "^${mark} " "$mark_file" | awk '{print $2}')
    if [ -z "$mark_timestamp" ]; then
        # mark not found
        log "WARN" "Mark $mark not found; considered older"
        return 0
    fi
    if [ "$mark_timestamp" -lt "$timestamp" ]; then
        log "DEBUG" "Mark $mark timestamp $mark_timestamp is older than $timestamp"
        return 0
    else
        log "DEBUG" "Mark $mark timestamp $mark_timestamp is not older than $timestamp"
        return 1
    fi
}