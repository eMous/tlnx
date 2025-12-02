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
	sudo chsh -s "$(which zsh)" "$user" 2>&1 | tee -a "$LOG_FILE" 

	if [ $? -eq 0 ]; then
		log "INFO" "ZSH set as the default shell for user $user"
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
	local current_shell=$(basename $SHELL)	
	log "INFO" "current shell is $current_shell"
	zsh_install
	if [ $? -ne 0 ]; then
		return 1
	fi

	if ! grep -qF "omzsh-setup" "$PROJECT_DIR/run/marks"; then
		ozsh_install
		ozsh_configure
		echo "omzsh-setup $(date +%s)" >> "$PROJECT_DIR/run/marks"
	else
		log "INFO" "Oh My Zsh already installed and configured as there is a mark; skipping"
	fi
	# This should behind ozsh_install and ozsh_configure, becasue the old http_proxy in bashrc may be needed during installation
	# if default log shell of the user is not zsh set it to zsh
	if [ "$(basename $(get_default_shell))" != "zsh" ]; then
		log "INFO" "Default shell is not ZSH, changing to ZSH"
		zsh_set_default
		if [ $? -ne 0 ]; then
			return 1
		fi
	else
		log "INFO" "Default shell is already ZSH; skipping default shell change"
	fi
	
	install_rc_file $current_shell
	log "INFO" "=== ZSH installation and configuration completed ==="
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

install_rc_file() {
	local original_shell=$1

	case "$original_shell" in
		zsh)
			;;
		bash)
			;;
		*)
			log "WARN" "Unsupported shell $original_shell; skipping rc file installation"
			exit 1;;
	esac

	local zshrc_file="$PROJECT_DIR/etc/.zshrc"
	if [ -f "$zshrc_file" ]; then
		log "INFO" "Installing ZSH rc file..."
		sudo mv "$HOME/.zshrc" "$HOME/.zshrc.$(date +%Y%m%d%H%M%S).bak" 2>&1 | tee -a "$LOG_FILE"
		: > $HOME/.zshrc
		append_shell_rc_block "$(cat "$zshrc_file")" "$HOME/.zshrc"
		init_tlnx_in_path
		# if set http proxy
		if [ -n "$http_proxy" ]; then
			set_http_proxy "$http_proxy"
		fi
		log "INFO" "ZSH rc file installed"
	else
		log "WARNING" "ZSH rc file not found; skipping installation"
	fi
}