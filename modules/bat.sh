#!/bin/bash

# bat module - install and configure bat

_bat_check_installed() {
	if command -v bat >/dev/null 2>&1; then
		return 0
	else
		return 1
	fi
}

# Module entrypoint for install workflow
_bat_install() {
	log "INFO" "=== Starting bat installation and configuration ==="
	log "INFO" "Installing bat..."
	sudo apt-get install -y bat > ${LOG_FILE} 2>&1
	log "INFO" "=== Finishing bat installation and configuration ==="
}
