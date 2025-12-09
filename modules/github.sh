#!/bin/bash

# GitHub module - configure SSH authentication for GitHub 

github_key_path() {
	echo "$HOME/.ssh/id_rsa_github"
}

github_ssh_config_block() {
	cat <<'EOF'
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_rsa_github
    IdentitiesOnly yes
EOF
}

github_auth_check() {
	local key_path=$1
	local ssh_output
		ssh_output=$(ssh ${key_path+"-i "$key_path" "} -o StrictHostKeyChecking=no -o BatchMode=yes -T git@github.com 2>&1)
	
	if echo "$ssh_output" | grep -q "successfully authenticated"; then
		return 0
	else
		log "WARN" "$ssh_output, GitHub authentication failed"
		return 1
	fi
}

_github_check_installed() {
	local key_path
	key_path=$(github_key_path)

	if [ ! -f "$key_path" ]; then
		log "INFO" "GitHub SSH key not found at $key_path"
		return 1
	fi

	if ! ssh-keygen -y -f "$key_path" >/dev/null 2>&1; then
		log "WARN" "Existing GitHub key at $key_path is invalid"
		return 1
	fi

	local ssh_config="$HOME/.ssh/config"
	if [ ! -f "$ssh_config" ] || ! grep -Fq "IdentityFile ~/.ssh/id_rsa_github" "$ssh_config"; then
		log "INFO" "GitHub SSH config entry missing"
		return 1
	fi

	if ! github_auth_check; then
		log "INFO" "Re-running GitHub module due to failed authentication check"
		return 1
	fi

	return 0
}

_github_install() {
	log "INFO" "=== Starting GitHub module ==="

	if [ -z "${GITHUB_PRIV_KEY_X:-}" ]; then
		log "ERROR" "GITHUB_PRIV_KEY_X is not set; cannot configure GitHub SSH access"
		return 1
	fi

	local key_path tmp_key
	key_path=$(github_key_path)
	tmp_key=$(mktemp)

	echo "$GITHUB_PRIV_KEY_X" >"$tmp_key"
	chmod 600 "$tmp_key"
	if ! ssh-keygen -y -f "$tmp_key" >/dev/null 2>&1; then
		log "ERROR" "Invalid GitHub private key provided in GITHUB_PRIV_KEY_X"
		rm -f "$tmp_key"
		return 1
	fi
	if ! github_auth_check "$tmp_key"; then
		rm -f "$tmp_key"
		return 1
	fi

	mkdir -p "$HOME/.ssh"
	mv "$tmp_key" "$key_path"
	chmod 600 "$key_path"
	log "INFO" "GitHub SSH private key installed to $key_path"

	local ssh_config="$HOME/.ssh/config"
	[ -f "$ssh_config" ] || touch "$ssh_config"
	chmod 600 "$ssh_config"
	local conf_entry
	conf_entry=$(github_ssh_config_block)
	if grep -Fq "$conf_entry" "$ssh_config"; then
		log "INFO" "GitHub SSH config already present; skipping update"
	else
		echo "$conf_entry" >>"$ssh_config"
		log "INFO" "GitHub SSH config entry added to $ssh_config"
	fi
	if ! github_auth_check; then
		return 1
	fi

	log "INFO" "=== GitHub module completed ==="
	return 0
}
