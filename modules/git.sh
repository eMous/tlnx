#!/bin/bash

# Git module - install and configure Git

git_module_mark_name() {
	echo "git-basic-setup"
}

git_module_mark_file() {
	echo "${PROJECT_DIR}/run/marks"
}

_git_check_installed() {
	local mark_file
	mark_file="$(git_module_mark_file)"
	local mark
	mark="$(git_module_mark_name)"

	if ! command -v git >/dev/null 2>&1; then
		log "DEBUG" "Git binary not found; module needs to run"
		return 1
	fi

	# if the default.conf or enc.conf is newer than the mark file, need to remove the mark
	# log the modification times for default.conf, enc.conf, and mark file
	local def_mod_time enc_mod_time
	def_mod_time=$(stat -c %Y "${PROJECT_DIR}/config/default.conf")
	enc_mod_time=$(stat -c %Y "${PROJECT_DIR}/config/enc.conf")
	if mark_older_than "$mark" "$def_mod_time" || mark_older_than "$mark" "$enc_mod_time"; then
		log "INFO" "Git module config files modified since last run; module will run"
		# remove the mark
		sed -i "/^${mark}.*$/d" "$mark_file"
	fi

	# check for the mark
	if [ -f "$mark_file" ] && grep -Fxq "$mark" "$mark_file"; then
		log "DEBUG" "Git module already applied (mark found)"
		return 0
	fi

	log "DEBUG" "Git module mark missing; module will run"
	return 1
}

git_install_packages() {
	if command -v git >/dev/null 2>&1; then
		log "INFO" "Git already installed; skipping package installation"
		return 0
	fi

	log "INFO" "Installing Git packages..."
	if ! sudo apt-get update >>"$LOG_FILE" 2>&1; then
		log "ERROR" "apt-get update failed while preparing for Git installation"
		return 1
	fi

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

	# Mark module as completed
	git_mark_complete
	log "INFO" "=== Git installation and configuration completed ==="
	return 0
}

git_mark_complete() {
	local mark_file
	mark_file="$(git_module_mark_file)"
	local mark
	mark="$(git_module_mark_name)"
	# if there is no mark in mark file, append it
	if [ ! -f "$mark_file" ] || ! grep -Fxq "$mark" "$mark_file"; then
		echo "${mark} $(date +%s)" >>"$mark_file"
		log "DEBUG" "Git module mark $mark added to $mark_file"
	else
		log "DEBUG" "Git module mark $mark already present in $mark_file"
	fi
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
