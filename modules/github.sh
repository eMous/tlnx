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
	if [ -z $key_path ]; then
		ssh_output=$(ssh -o StrictHostKeyChecking=no -o BatchMode=yes -T git@github.com 2>&1)
	else
		ssh_output=$(ssh -i "$key_path" -o StrictHostKeyChecking=no -o BatchMode=yes -T git@github.com 2>&1)
	fi
	if echo "$ssh_output" | grep -q "successfully authenticated"; then
		return 0
	else
		log "WARN" "$ssh_output, GitHub authentication failed"
		return 1
	fi
}

github_install() {
	log "INFO" "Installing gh.."
	if command -v gh >/dev/null 2>&1; then
		log "INFO" "gh is already installed; skipping"
		return 0
	fi
	
	(type -p wget >/dev/null || (sudo apt update && sudo apt install wget -y)) \
	&& sudo mkdir -p -m 755 /etc/apt/keyrings \
	&& out=$(mktemp) && wget -nv -O$out https://cli.github.com/packages/githubcli-archive-keyring.gpg \
	&& cat $out | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
	&& sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
	&& sudo mkdir -p -m 755 /etc/apt/sources.list.d \
	&& echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
	&& sudo apt update \
	&& sudo apt install gh -y

	return 0
}

_github_install() {
	log "INFO" "=== Starting GitHub module ==="

	github_install

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

