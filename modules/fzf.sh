#!/bin/bash

# fzf module - install and configure fzf

_fzf_check_installed() {
	if command -v fzf >/dev/null 2>&1; then
		return 0
	else
		return 1
	fi
}

# Module entrypoint for install workflow
_fzf_install() {
	log "INFO" "=== Starting fzf installation and configuration ==="
	log "INFO" "Installing fzf..."
	install_package_binary "fzf"
	log "INFO" "=== Finishing fzf installation and configuration ==="
}
