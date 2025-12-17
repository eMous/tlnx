#!/bin/bash

# nvim module - install and configure nvim

_nvim_check_installed() {
	if command -v nvim >/dev/null 2>&1; then
		return 0
	else
		return 1
	fi
}

# Module entrypoint for install workflow
_nvim_install() {
	log "INFO" "=== Starting nvim installation and configuration ==="
	log "INFO" "Installing nvim..."
	install_package_binary "nvim" "nvim" "bin"
	_nvim_configure
	log "INFO" "=== Finishing nvim installation and configuration ==="
}
