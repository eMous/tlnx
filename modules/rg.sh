#!/bin/bash

# rg module - install and configure rg
# Install rg
# Module entrypoint for install workflow
_rg_install() {
	log "INFO" "=== Starting rg installation and configuration ==="
	if command -v rg >/dev/null 2>&1; then
		log "INFO" "rg already installed; skipping installation"
		return 0
	fi

	log "INFO" "Installing rg..."
	# local package_name="ripgrep"
	# if ! checkout_package_file "$package_name"; then
	# 	log "ERROR" "Failed to checkout package file for $package_name"
 	#     return 1
	# fi
    
	# local extracted_dir="$PROJECT_DIR/run/packages/$package_name"
    # cd $extracted_dir
	# rsync -a rg $HOME/.local/bin/
	sudo apt-get install -y ripgrep
	log "INFO" "=== Finishing ripgrep installation and configuration ==="
}
