#!/bin/bash

# ZeroTier module - install and configure ZeroTier

zerotier_install() {
	if command -v zerotier-cli >/dev/null 2>&1; then
		log "INFO" "ZeroTier is already installed"
		return 0
	fi

	log "INFO" "Installing ZeroTier..."
	curl -s https://install.zerotier.com | sudo bash 2>&1 | tee -a "$LOG_FILE"
	
	if [ $? -eq 0 ]; then
		log "INFO" "ZeroTier installed successfully"
	else
		log "ERROR" "ZeroTier installation failed"
		return 1
	fi
}

zerotier_join() {
	local net_id="${ZEROTIER_NETWORK_ID:-}"
	
	if [ -z "$net_id" ]; then
		log "WARN" "ZEROTIER_NETWORK_ID not set, skipping network join"
		return 0
	fi

	log "INFO" "Joining ZeroTier network: $net_id"
	sudo zerotier-cli join "$net_id" 2>&1 | tee -a "$LOG_FILE"
	
	if [ $? -eq 0 ]; then
		log "INFO" "Joined ZeroTier network $net_id"
	else
		log "ERROR" "Failed to join ZeroTier network $net_id"
		return 1
	fi
}

_zerotier_install() {
	log "INFO" "=== Starting ZeroTier module ==="
	zerotier_install
	zerotier_join
	log "INFO" "=== ZeroTier module completed ==="
}
