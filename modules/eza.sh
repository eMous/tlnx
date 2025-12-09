#!/bin/bash

# eza module - install and configure eza
# Install eza
# Module entrypoint for install workflow
_eza_install() {
	log "INFO" "=== Starting eza installation and configuration ==="
	if command -v eza >/dev/null 2>&1; then
		log "INFO" "eza already installed; skipping installation"
		return 0
	fi

	log "INFO" "Installing eza..."
	local package_name="eza"
	if ! checkout_package_file "$package_name"; then
		log "ERROR" "Failed to checkout package file for $package_name"
		return 1
	fi

	local extracted_dir="$PROJECT_DIR/run/packages/$package_name"
	cd $extracted_dir
	rsync -a eza $HOME/.local/bin/
	log "INFO" "=== Finishing eza installation and configuration ==="
}
