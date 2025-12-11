#!/bin/bash

# Clashctl module - install and configure Clash and Clashctl

# Module entrypoint
run_clash_install_cmd() {
	local cmd="$1"
	if [ -t 0 ] && [ -t 1 ]; then
		command sudo bash -lc "$cmd"
		return $?
	fi
	if command -v script >/dev/null 2>&1; then
		log "INFO" "Wrapping Clashctl command in script(1) to emulate a TTY"
		command sudo script -qefc "$cmd" /dev/null
	else
		log "WARN" "Non-interactive terminal and 'script' missing; running Clashctl command without TTY"
		command sudo bash -lc "$cmd"
	fi
}

_clashctl_install() {
	log "INFO" "=== Starting Clashctl module ==="

	log "INFO" "Installing clash-for-linux-install..."
	local package_name="clash-for-linux-install"
	if ! checkout_package_file "$package_name"; then
		log "ERROR" "Failed to checkout package file for $package_name"
		return 1
	fi

	local extracted_dir="$PROJECT_DIR/run/packages/$package_name"
	cd $extracted_dir

	if [ -n "${CLASHCTL_SUB_X:-}" ]; then
		curl -L "${CLASHCTL_SUB_X}" -o resources/config.yaml 2>&1 | tee -a "$LOG_FILE"
	fi

	local uninstall_cmd="cd '$extracted_dir' && $(get_current_shell) uninstall.sh"
	run_clash_install_cmd "$uninstall_cmd" 2>&1 | tee -a "$LOG_FILE"
	local uninstall_status=${PIPESTATUS[0]}
	if [ $uninstall_status -ne 0 ]; then
		log "ERROR" "Clash uninstall script failed"
		return 1
	fi

	local install_cmd="cd '$extracted_dir' && $(get_current_shell) install.sh"
	run_clash_install_cmd "$install_cmd" 2>&1 | tee -a "$LOG_FILE"
	local install_status=${PIPESTATUS[0]}
	if [ $install_status -ne 0 ]; then
		log "ERROR" "Clash install script failed"
		return 1
	fi

	local output=$(bash -ci 'clashon >/dev/null 2>&1; echo $http_proxy;')
	export http_proxy=$(echo $output | grep -o "http://[^ ]*")
	export https_proxy=$http_proxy
	export HTTP_PROXY=$http_proxy
	export HTTPS_PROXY=$http_proxy

	log "INFO" "=== Clashctl module completed ==="
	return 0
}
_clashctl_zsh_post_install_callback() {
	_clashctl_install
	cat ~/.bashrc
}
