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
			if command -v "decrypt" &>/dev/null; then
				DEFAULT_KEY_ENV=${CONFIG_DEFAULT_KEY_ENV:-"CONFIG_KEY"}

				if "decrypt" "${PROJECT_DIR}/config/enc.conf.enc" "${PROJECT_DIR}/config/enc.conf" "$DEFAULT_KEY_ENV"; then
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
				log "WARN" "decrypt not found; skipping decryption"
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
	local config_file="$PROJECT_DIR/config/default.conf"

	if [ -f "$config_file" ]; then
		# Identify variables defined in config file to prevent them from overwriting environment variables
		local config_vars
		# Extract variable names assigned at the start of the line (e.g. VAR=value)
		config_vars=$(grep -E '^[A-Z_][a-zA-Z0-9_]*=' "$config_file" | cut -d= -f1)
		
		# Stash existing environment variables
		local -A env_stash
		local var
		for var in $config_vars; do
			# Check if variable is set in current environment
			if [ -n "${!var+x}" ]; then
				env_stash["$var"]="${!var}"
			fi
		done

		. "$config_file"
		log "INFO" "Default configuration loaded"

		# Restore stashed variables
		for var in "${!env_stash[@]}"; do
			local val="${env_stash[$var]}"
			printf -v "$var" '%s' "$val"
			log "INFO" "Restored environment variable $var over config default"
		done
	else
		log "ERROR" "Default configuration missing: $config_file"
		echo "Default configuration missing: $config_file"
		return 1
	fi
	decrypt_config

	if [ -z "${CONFIG_MODULES+set}" ] && [ -n "${MODULES+set}" ]; then
		CONFIG_MODULES=("${MODULES[@]}")
	fi

	TARGET_HOST="$REMOTE_ENC_HOST_X"
	TARGET_USER="$REMOTE_ENC_USER_X"
	TARGET_PORT="$REMOTE_ENC_PORT_X"
	TARGET_PASSWORD="$REMOTE_ENC_PASSWORD_X"
}

get_proxy_value_from_configs() {
	local key="$1"
	local files=("$PROJECT_DIR/config/enc.conf" "$PROJECT_DIR/config/default.conf")

	for file in "${files[@]}"; do
		if [ ! -f "$file" ]; then
			continue
		fi

		local line value
		line=$(grep -E "^${key}=" "$file" | tail -n 1)
		if [ -z "$line" ]; then
			continue
		fi

		value="${line#*=}"
		value="${value%\"}"
		value="${value#\"}"
		if [ -n "$value" ]; then
			echo "$value"
			return 0
		fi
	done
	return 1
}
