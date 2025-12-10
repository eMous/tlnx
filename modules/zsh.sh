#!/bin/bash

# ZSH module - install and configure ZSH
# Install ZSH
zsh_install() {
	log "INFO" "Installing and configuring ZSH..."

	if ! command -v zsh >/dev/null 2>&1; then
		# Refresh package list
		sudo apt-get update 2>&1 | tee -a "$LOG_FILE"
		# Install ZSH
		sudo apt-get install -y zsh 2>&1 | tee -a "$LOG_FILE"
		if [ $? -ne 0 ]; then
			log "ERROR" "ZSH installation failed"
			return 1
		fi
	else
		log "INFO" "ZSH is already installed, skipping installation"
		return 0
	fi
}

# Make ZSH the default shell
zsh_set_default() {
	log "INFO" "Setting ZSH as the default shell..."
	# Determine current user
	local current_user=$(whoami)
	# Update default shell for the user
	local user=$(whoami)
	command sudo chsh -s "$(which zsh)" "$user" 2>&1 | tee -a "$LOG_FILE"
}

# Module entrypoint for install workflow
_zsh_install() {
	log "INFO" "=== Starting ZSH installation and configuration ==="
	local current_shell=$(get_current_shell)
	log "INFO" "current shell is $current_shell"
	zsh_install
	if ! command -v zsh >/dev/null 2>&1; then
		log "ERROR" "ZSH installation failed; aborting ZSH module"
		return 1
	fi

	if [ "$(basename $(get_default_shell))" != "zsh" ]; then
		log "INFO" "Default shell is not ZSH, changing to ZSH"
		zsh_set_default
		if [ $? -ne 0 ]; then
			return 1
		fi
	else
		log "INFO" "Default shell is already ZSH; skipping default shell change"
	fi

	configure_zdot

	zsh -ci "echo 'ZSH installation and configuration successful.'" 2>&1 | tee -a "$LOG_FILE"

	log "INFO" "=== ZSH installation and configuration completed ==="
}

configure_zdot() {
	log "INFO" "Configuring ZDOTDIR for ZSH..."
	touch "$HOME/.zshenv"
	local content=$(
	cat <<EOF
export ZDOTDIR="\$HOME/.config/zsh"
[[ -f "\$ZDOTDIR/.zshenv" ]] && source "\$ZDOTDIR/.zshenv"
EOF
	)
	append_shell_rc_sub_block "zshenv zdotdir config" "$content" "$HOME/.zshenv"
	log "INFO" "ZDOTDIR configured to $HOME/.config/zsh"
}
