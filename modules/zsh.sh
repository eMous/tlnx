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

	log "VERBOSE" "Starting decrypt function"		log "WARN" "Failed to set ZSH as the default shell; manual intervention may be required"
	fi
}

# Module entrypoint for install workflow
_zsh_install() {
	log "INFO" "=== Starting ZSH installation and configuration ==="
	local current_shell=$(get_currentshell)
	log "INFO" "current shell is $current_shell"
	zsh_install
	if ! command -v zsh >/dev/null 2>&1; then
		log "ERROR" "ZSH installation failed; aborting ZSH module"
		return 1
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
	
	install_zshconf_files
	install_rc_patch
	install_zimfw

	log "INFO" "=== ZSH installation and configuration completed ==="
}

install_zshconf_files() {
	local files=("$PROJECT_DIR/etc/.zshenv" "$PROJECT_DIR/etc/.zshrc")
	for file in "${files[@]}"; do
		local filename=$(basename "$file")
		local target="$HOME/$filename"
		if [ ! -f "$file" ]; then
			log "WARN" "ZSH configuration file $file not found; skipping installation"
			continue
		fi
		# if target exists and ( file new than target  OR target is not exist ) then backup and install
		if [ -f "$target" ] && [ "$target" -nt "$file" ]; then
			log "INFO" "$filename exists and is newer than the template; skipping installation"
			continue
		fi
		
		if [  -f "$target" ] ; then
			mv "$target" "$target.$(date +%Y%m%d%H%M%S).bak" 2>&1 | tee -a "$LOG_FILE"
			log "INFO" "Existing $filename backed up to $filename.$(date +%Y%m%d%H%M%S).bak"
		fi
		append_shell_rc_sub_block "$filename template" "$(cat "$file")" "$target"
		log "INFO" "$filename updated"
	done
}
install_rc_patch() {
	local zshrc_file="$PROJECT_DIR/etc/.zshrc"
	if [ -f "$zshrc_file" ]; then
		init_tlnx_in_path $(which zsh)
		# if set http proxy
		if [ -n "$http_proxy" ]; then
			set_http_proxy "$http_proxy" "$HOME/.zshrc"
		fi
	else 
		log "WARN" "ZSH rc file not found; skipping patch"
	fi
}
install_zimfw() {
	local mark="zsh_zimfw_installed_mark"
	if mark_exists "$mark"; then
		log "INFO" "Zimfw already installed; skipping installation"
		return 0
	fi

	log "INFO" "Installing Zimfw..."
	checkout_package_file "zsh"
	mkdir -p "$HOME/.zim"
	mkdir -p "$HOME/.config/zsh"
	export ZIM_HOME="$HOME/.zim"
	export ZIM_CONFIG_FILE="$HOME/.config/zsh/zimrc"
	cp "$PROJECT_DIR/run/packages/zsh/zimfw.zsh" "$HOME/.zim/zimfw.zsh"
	if [ ! -f "${ZIM_CONFIG_FILE:-${ZDOTDIR:-${HOME}}/.zimrc}" ] || [ $PROJECT_DIR/etc/.zimrc -nt ${ZIM_CONFIG_FILE:-${ZDOTDIR:-${HOME}}/.zimrc} ]; then
		cp $PROJECT_DIR/etc/.zimrc "${ZIM_CONFIG_FILE:-${ZDOTDIR:-${HOME}}/.zimrc}"
	fi
	# Install missing modules and update ${ZIM_HOME}/init.zsh if missing or outdated.
	add_mark "$mark"
	return 0
}
_zsh_check_installed() {
	local module=$1
	local mark=$2
	local marks_file=$3
	local zshrc_file="$PROJECT_DIR/etc/.zshrc"
	if ! mark_exists "zsh_zimfw_installed_mark" "$marks_file"; then
		log "INFO" "${module} module not installed (mark not found)"
		return 1
	fi
	if [ ! -f "$HOME/.zshrc" ]; then
		log "DEBUG" "$HOME/.zshrc file not found; assuming module needs to run"
		return 1
	fi
	if  ! mark_older_than "$mark" "$(stat -c %Y "$zshrc_file")" ; then
		log "DEBUG" "${module} module already applied (mark found)"
		return 0
	else
		log "INFO" "${module} module config files modified since last run; module will run"
		# remove the mark
		sed -i "/^${mark}.*$/d" "$marks_file"
		return 1
	fi
}

# install_rc_file() {
# 	local original_shell=$1

# 	case "$original_shell" in
# 		zsh)
# 			;;
# 		bash)
# 			;;
# 		*)
# 			log "WARN" "Unsupported shell $original_shell; skipping rc file installation"
# 			exit 1;;
# 	esac

# 	local zshrc_file="$PROJECT_DIR/etc/.zshrc"
# 	if [ -f "$zshrc_file" ]; then
# 		log "INFO" "Installing ZSH rc file..."
# 		sudo mv "$HOME/.zshrc" "$HOME/.zshrc.$(date +%Y%m%d%H%M%S).bak" 2>&1 | tee -a "$LOG_FILE"
# 		: > $HOME/.zshrc
# 		append_shell_rc_sub_block "zshrc template" "$(cat "$zshrc_file")" "$HOME/.zshrc"
# 		init_tlnx_in_path $(which zsh)
# 		# if set http proxy
# 		if [ -n "$http_proxy" ]; then
# 			set_http_proxy "$http_proxy" "$HOME/.zshrc"
# 		fi
# 		log "INFO" "ZSH rc file installed"
# 	else
# 		log "WARN" "ZSH rc file not found; skipping installation"
# 	fi
# }