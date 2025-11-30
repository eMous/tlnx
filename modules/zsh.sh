#!/bin/bash

# ZSH module - install and configure ZSH

# Check whether ZSH is already installed
_zsh_check_installed() {
	if command -v zsh >/dev/null 2>&1; then
		log "DEBUG" "ZSH already installed"
		return 0
	else
		log "DEBUG" "ZSH not installed"
		return 1
	fi
}

# Install ZSH
zsh_install() {
	log "INFO" "Installing ZSH..."

	# Refresh package list
	sudo apt-get update >>"$LOG_FILE" 2>&1

	# Install ZSH
	sudo apt-get install -y zsh >>"$LOG_FILE" 2>&1

	if [ $? -eq 0 ]; then
		log "INFO" "ZSH installation succeeded"
	else
		log "ERROR" "ZSH installation failed"
		return 1
	fi
}

# Make ZSH the default shell
zsh_set_default() {
	log "INFO" "Setting ZSH as the default shell..."

	# Determine current user
	local current_user=$(whoami)

	# Update default shell for the user
	chsh -s $(which zsh) >>"$LOG_FILE" 2>&1

	if [ $? -eq 0 ]; then
		log "INFO" "ZSH set as the default shell"
	else
		log "WARNING" "Failed to set ZSH as the default shell; manual intervention may be required"
	fi
}

# Install Oh My Zsh
ozsh_install() {
	log "INFO" "Installing Oh My Zsh..."

	# Download and run the installer
	sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" >>"$LOG_FILE" 2>&1 || true

	if [ -d "$HOME/.oh-my-zsh" ]; then
		log "INFO" "Oh My Zsh installation succeeded"
	else
		log "WARNING" "Oh My Zsh installation failed; skipping"
	fi
}

# Configure ZSH
ozsh_configure() {
	log "INFO" "Configuring ZSH..."

	# Choose theme from config or default
	local theme=${ZSH_THEME:-"robbyrussell"}

	# Check the ~/.zshrc file
	if [ -f "$HOME/.zshrc" ]; then
		# Backup the existing config
		cp "$HOME/.zshrc" "$HOME/.zshrc.bak" >>"$LOG_FILE" 2>&1

		# Update the theme
		sed -i "s/ZSH_THEME=.*/ZSH_THEME=\"$theme\"/" "$HOME/.zshrc" >>"$LOG_FILE" 2>&1

		log "INFO" "ZSH configuration updated"
	else
		log "WARNING" "~/.zshrc file not found; skipping configuration"
	fi
}

# Module entrypoint for install workflow
_zsh_install() {
	log "INFO" "=== Starting ZSH installation and configuration ==="

	zsh_install
	if [ $? -ne 0 ]; then
		return 1
	fi

	zsh_set_default
	ozsh_install
	ozsh_configure

	log "INFO" "=== ZSH installation and configuration completed ==="
	return 0
}
