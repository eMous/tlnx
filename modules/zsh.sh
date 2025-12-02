#!/bin/bash

# ZSH module - install and configure ZSH
zsh_installed_mark() {
	echo "zsh-installed"
}

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
	sudo chsh -s $(which zsh) $(whoami) 2>&1 | tee -a "$LOG_FILE" 

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
	sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended 2>&1 | tee -a "$LOG_FILE"

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
		cp "$HOME/.zshrc" "$HOME/.zshrc.bak" 2>&1 | tee -a "$LOG_FILE"

		# Update the theme
		sed -i "s/ZSH_THEME=.*/ZSH_THEME=\"$theme\"/" "$HOME/.zshrc" 2>&1 | tee -a "$LOG_FILE"

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

_zsh_check_installed() {
	local module=$1
	local mark=$2
	local marks_file=$3
	local zshrc_file="$PROJECT_DIR/etc/.zshrc"
	if ! mark_older_than "$mark" "$(stat -c %Y "$zshrc_file")"; then
		log "DEBUG" "${module} module already applied (mark found)"
		return 0
	else
		log "INFO" "${module} module config files modified since last run; module will run"
		# remove the mark
		sed -i "/^${mark}.*$/d" "$marks_file"
		return 1
	fi
}