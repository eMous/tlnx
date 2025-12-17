#!/bin/bash

# eza module - install and configure eza
# Install eza

_eza_check_installed() {
	if command -v eza >/dev/null 2>&1; then
		return 0
	else
		return 1
	fi
}

# Module entrypoint for install workflow
_eza_install() {
	log "INFO" "=== Starting eza installation and configuration ==="
	log "INFO" "Installing eza..."
	install_package_binary "eza"
	log "INFO" "=== Finishing eza installation and configuration ==="
}
