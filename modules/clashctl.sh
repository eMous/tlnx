#!/bin/bash

# Clashctl module - install and configure Clash and Clashctl

# Module entrypoint
_clashctl_install() {
	log "INFO" "=== Starting Clashctl module ==="
 
	log "INFO" "Installing clash-for-linux-install..."
	local package_name="clash-for-linux-install"
	if ! checkout_package_file "$package_name"; then
		log "ERROR" "Failed to checkout package file for $package_name"
 	    return 1
	fi
    
	local extracted_dir="$PROJECT_DIR/run/packages/$package_name"
    cd $extracted_dir
    
    local clash_config;
    if [ -n "${CLASHCTL_SUB_X:-}" ]; then
        curl -L "${CLASHCTL_SUB_X}" -o resources/config.yaml 2>&1 | tee -a "$LOG_FILE"
    fi
    command sudo $(get_current_shell) uninstall.sh 2>&1 | tee -a "$LOG_FILE" 
    command sudo $(get_current_shell) install.sh 2>&1 | tee -a "$LOG_FILE"

	log "INFO" "=== Clashctl module completed ==="
	return 0
}
