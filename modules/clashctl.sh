#!/bin/bash

# Clashctl module - install and configure Clash and Clashctl

# Module entrypoint
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

	local clash_config
	if [ -n "${CLASHCTL_SUB_X:-}" ]; then
		curl -L "${CLASHCTL_SUB_X}" -o resources/config.yaml 2>&1 | tee -a "$LOG_FILE"
	fi

	command sudo $(get_current_shell) uninstall.sh 2>&1 | tee -a "$LOG_FILE"
	command sudo $(get_current_shell) install.sh 2>&1 | tee -a "$LOG_FILE"

	local output=$(bash -ci 'clashon >/dev/null 2>&1; echo $http_proxy;')
	export http_proxy=$(echo $output | grep -o "http://[^ ]*")
	export https_proxy=$http_proxy
	export HTTP_PROXY=$http_proxy
	export HTTPS_PROXY=$http_proxy
	log "INFO" "Set http_proxy for clashctl: $http_proxy"
	log "INFO" "Set https_proxy for clashctl: $http_proxy"
	log "INFO" "Set HTTP_proxy for clashctl: $http_proxy"
	log "INFO" "Set HTTPS_proxy for clashctl: $http_proxy"
	bash -ci 'clashctl proxy'
	
	log "INFO" "=== Clashctl module completed ==="

	_clashctl_shell_patch $HOME/.bashrc
	return 0
}
_clashctl_zsh_post_install_callback() {
	_clashctl_shell_patch $HOME/.zshrc
}

_clashctl_shell_patch() {
	local rc_file="$1"


	local content=$(cat <<'EOF'
clashctl_patch() {
local file1="/opt/clash/script/common.sh"
local file2="/opt/clash/script/clashctl.sh"
source "$file1" && source "$file2"
# Check mihomo service running
if ! systemctl is-active --quiet mihomo; then
	echo "[Mihomo Service] Mihomo is not running, you may manually run clashon."
else 
	MIXED_PORT=$($BIN_YQ '.mixed-port' "$CLASH_CONFIG_RUNTIME")
	if [ -z "$MIXED_PORT" ] || [ "$MIXED_PORT" == "null" ]; then
		echo "[Clashctl] Unable to determine mixed-port from $CLASH_CONFIG_RUNTIME"
	else
		unset http_proxy
		unset https_proxy
		unset HTTP_PROXY
		unset HTTPS_PROXY
		export http_proxy="http://127.0.0.1:$MIXED_PORT"
		export https_proxy="$http_proxy"
		export HTTP_PROXY="$http_proxy"
		export HTTPS_PROXY="$http_proxy"
	fi
fi
}
clashctl_patch
EOF
	)
	
	if grep -Fq "clashctl_patch" "$rc_file"; then
		log "INFO" "clashctl patch already found in $rc_file, skipping addition."
		return 0
	fi
    log "INFO" "Patching clashctl into shell rc file: $rc_file"
	append_shell_rc_sub_block "clashctl patch" "$content" "$rc_file"
}