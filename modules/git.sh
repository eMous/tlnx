#!/bin/bash

# Git module - install and configure Git

git_module_mark_name() {
	echo "git-basic-setup"
}

git_module_mark_file() {
	echo "${TLNX_DIR}/run/marks"
}

git_install_packages() {
	if command -v git >/dev/null 2>&1; then
		log "INFO" "Git already installed; skipping package installation"
		return 0
	fi

	log "INFO" "Installing Git packages..."
	# if ! sudo apt-get update >>"$LOG_FILE" 2>&1; then
	# 	log "ERROR" "apt-get update failed while preparing for Git installation"
	# 	return 1
	# fi

	if ! sudo apt-get install -y git >>"$LOG_FILE" 2>&1; then
		log "ERROR" "Failed to install Git via apt"
		return 1
	fi

	log "INFO" "Git installation succeeded"
	return 0
}

git_require_command() {
	if ! command -v git >/dev/null 2>&1; then
		log "ERROR" "Git command not found; cannot continue Git module"
		return 1
	fi
}

git_configure_identity() {
	git_require_command || return 1

	local configured="false"


	
	if [ -n "${GIT_USER_NAME_X:-}" ]; then
		if git config --global user.name "$GIT_USER_NAME_X" >>"$LOG_FILE" 2>&1; then
			log "INFO" "Configured git user.name as $GIT_USER_NAME_X"
			configured="true"
		else
			log "WARN" "Failed to set git user.name"
		fi
	else
		log "DEBUG" "GIT_USER_NAME not provided; skipping user.name configuration"
	fi

	if [ -n "${GIT_USER_EMAIL_X:-}" ]; then
		if git config --global user.email "$GIT_USER_EMAIL_X" >>"$LOG_FILE" 2>&1; then
			log "INFO" "Configured git user.email as $GIT_USER_EMAIL_X"
			configured="true"
		else
			log "WARN" "Failed to set git user.email"
		fi
	else
		log "DEBUG" "GIT_USER_EMAIL not provided; skipping user.email configuration"
	fi

	if [ "$configured" = "false" ]; then
		log "INFO" "No Git identity overrides configured; skipping"
	fi

	return 0
}

git_trim_whitespace() {
	local input="$1"
	input="${input#"${input%%[![:space:]]*}"}"
	input="${input%"${input##*[![:space:]]}"}"
	printf '%s' "$input"
}

git_configure_preferences() {
	git_require_command || return 1

	local configured="false"

	if declare -p GIT_CONFIGS >/dev/null 2>&1; then
		local entry
		for entry in "${GIT_CONFIGS[@]}"; do
			if [ -z "$entry" ]; then
				continue
			fi

			if [[ "$entry" != *"="* ]]; then
				log "WARN" "Skipping invalid Git config entry (expected key=value): $entry"
				continue
			fi

			local key_raw="${entry%%=*}"
			local val_raw="${entry#*=}"
			local key value
			key=$(git_trim_whitespace "$key_raw")
			value=$(git_trim_whitespace "$val_raw")

			if [ -z "$key" ]; then
				log "WARN" "Skipping Git config entry with empty key: $entry"
				continue
			fi

			if git config --global "$key" "$value" >>"$LOG_FILE" 2>&1; then
				log "INFO" "Set git config $key=$value"
				configured="true"
			else
				log "WARN" "Failed to set git config $key"
			fi
		done
	else
		log "DEBUG" "GIT_CONFIGS not defined; skipping additional Git config values"
	fi

	if [ "$configured" = "false" ]; then
		log "INFO" "No Git preference overrides configured; skipping"
	fi

	return 0
}


_git_install() {
	log "INFO" "=== Starting Git installation and configuration ==="

	if ! git_install_packages; then
		log "ERROR" "Git package installation failed"
		return 1
	fi

	if ! command -v git >/dev/null 2>&1; then
		log "ERROR" "Git command missing after installation attempt"
		return 1
	fi

	if ! git_configure_identity; then
		return 1
	fi

	if ! git_configure_preferences; then
		return 1
	fi

	if ! git_configure_proxy; then
		return 1
	fi

	log "INFO" "=== Git installation and configuration completed ==="
	return 0
}

git_configure_proxy() {
	git_require_command || return 1

	if [ "${GIT_PROXY_AUTO_DETECT:-true}" = "true" ]; then
		if [ -n "$http_proxy" ]; then
			if git config --global http.proxy "$http_proxy" >>"$LOG_FILE" 2>&1; then
				log "INFO" "Configured git http.proxy as $http_proxy"
			else
				log "WARN" "Failed to set git http.proxy"
			fi
		else
			log "INFO" "No HTTP proxy detected; skipping git proxy configuration and try to unset existing settings"
			git config --global --unset http.proxy >>"$LOG_FILE" 2>&1
		fi
		if [ -n "$https_proxy" ]; then
			if git config --global https.proxy "$https_proxy" >>"$LOG_FILE" 2>&1; then
				log "INFO" "Configured git https.proxy as $https_proxy"
			else
				log "WARN" "Failed to set git https.proxy"
			fi
		else
			log "INFO" "No HTTPS proxy detected; skipping git proxy configuration and try to unset existing settings"
			git config --global --unset https.proxy >>"$LOG_FILE" 2>&1
		fi
	else
		log "DEBUG" "GIT_PROXY_AUTO_DETECT not enabled; skipping git proxy configuration"
	fi

	return 0
}
