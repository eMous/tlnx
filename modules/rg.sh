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
	sudo apt-get install -y ripgrep
	log "INFO" "=== Finishing ripgrep installation and configuration ==="
}
