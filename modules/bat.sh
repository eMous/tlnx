#!/bin/bash

# bat module - install and configure bat
# Install bat
# Module entrypoint for install workflow
_bat_install() {
	log "INFO" "=== Starting bat installation and configuration ==="
	if command -v bat >/dev/null 2>&1; then
		log "INFO" "bat already installed; skipping installation"
		return 0
	fi

	log "INFO" "Installing bat..."
	# local package_name="bat"
	# if ! checkout_package_file "$package_name"; then
	# 	log "ERROR" "Failed to checkout package file for $package_name"
 	#     return 1
	# fi
    
	# local extracted_dir="$PROJECT_DIR/run/packages/$package_name"
    # cd $extracted_dir
	# rsync -a bat $HOME/.local/bin/
	sudo apt-get install -y bat
	log "INFO" "=== Finishing ripgrep installation and configuration ==="
}
