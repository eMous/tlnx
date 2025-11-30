#!/bin/bash

# Decrypt configuration when encrypted file exists
decrypt_config() {
	log "INFO" "Checking for encrypted configuration..."

	if [ -f "${PROJECT_DIR}/config/enc.conf.enc" ]; then
		if [ -f "${PROJECT_DIR}/config/enc.conf" ] && [ "${PROJECT_DIR}/config/enc.conf" -nt "${PROJECT_DIR}/config/enc.conf.enc" ]; then
			log "INFO" "Decrypted config is newer than encrypted source; loading"
			source "${PROJECT_DIR}/config/enc.conf"
			log "INFO" "Encrypted configuration loaded"
			return 0
		else
			if [ ! -f "${PROJECT_DIR}/config/enc.conf" ]; then
				log "INFO" "Decrypted config missing; running decryption"
			else
				log "INFO" "Decrypted config older than encrypted file; running decryption"
			fi

			if [ -f "${PROJECT_DIR}/scripts/decrypt.sh" ]; then
				DEFAULT_KEY_ENV=${CONFIG_DEFAULT_KEY_ENV:-"CONFIG_KEY"}

				if . "${PROJECT_DIR}/scripts/decrypt.sh" "${PROJECT_DIR}/config/enc.conf.enc" "${PROJECT_DIR}/config/enc.conf" "$DEFAULT_KEY_ENV"; then
					log "INFO" "Encrypted config decrypted"

					if [ -f "${PROJECT_DIR}/config/enc.conf" ]; then
						log "INFO" "Loading decrypted configuration"
						source "${PROJECT_DIR}/config/enc.conf"
						log "INFO" "Encrypted configuration loaded"
						return 0
					else
						log "ERROR" "Decrypted configuration missing"
						return 1
					fi
				else
					log "ERROR" "Failed to decrypt encrypted configuration"
					return 1
				fi
			else
				log "WARNING" "${PROJECT_DIR}/scripts/decrypt.sh not found; skipping decryption"
				return 1
			fi
		fi
	else
		log "INFO" "Encrypted configuration not found; skipping"
		return 1
	fi
}

# Load default configuration
_load_config() {
	log "INFO" "Loading default configuration..."
	if [ -f $PROJECT_DIR"/config/default.conf" ]; then
		. "$PROJECT_DIR/config/default.conf"
		log "INFO" "Default configuration loaded"
	else
		log "ERROR" "Default configuration missing: $PROJECT_DIR/config/default.conf"
		echo "Default configuration missing: $PROJECT_DIR/config/default.conf"
		return 1
	fi
	decrypt_config

	if [ -z "${CONFIG_MODULES+set}" ] && [ -n "${MODULES+set}" ]; then
		CONFIG_MODULES=("${MODULES[@]}")
	fi

	TARGET_HOST="$TARGET_ENC_HOST"
	TARGET_USER="$TARGET_ENC_USER"
	TARGET_PORT="$TARGET_ENC_PORT"
	TARGET_PASSWORD="$TARGET_ENC_PASSWORD"
}
