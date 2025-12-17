#!/bin/bash

# Clashctl module - install and configure Clash and Clashctl

_clashctl_check_installed() {
	if command -v clashctl >/dev/null 2>&1; then
		log "INFO" "Clashctl is already installed."
	else
		log "INFO" "Clashctl is not installed."
		return 1
	fi
	if command -v watch_proxy >/dev/null 2>&1; then
		log "INFO" "watch_proxy is already installed."
	else
		log "INFO" "watch_proxy is not installed."
		return 1
	fi
	if zsh -ci "command -v clashctl" >/dev/null 2>&1; then
		log "INFO" "clashctl is already installed in zsh."
	else
		log "INFO" "clashctl is not installed in zsh."
		return 1
	fi
	if zsh -ci "command -v watch_proxy" >/dev/null 2>&1; then
		log "INFO" "watch_proxy is already installed in zsh."
	else
		log "INFO" "watch_proxy is not installed in zsh."
		return 1
	fi
	return 0
}

# Module entrypoint
_clashctl_install() {
	log "INFO" "=== Starting Clashctl module ==="

	log "INFO" "Installing clash-for-linux-install..."
	local package_name="clash-for-linux-install"
	# Package is already extracted in packages/clash-for-linux-install
	local extracted_dir="$TLNX_DIR/packages/$package_name"
	
	if [ ! -d "$extracted_dir" ]; then
		log "ERROR" "Package directory $extracted_dir does not exist"
		return 1
	fi

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

	_clashctl_shell_patch $(get_rc_file $(get_current_shell))
	return 0
}
_clashctl_zsh_post_install_callback() {
	_clashctl_shell_patch $(get_rc_file zsh)
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

clashr() {
	sudo $BIN_YQ -i '.mode = "rule"' "$CLASH_CONFIG_RUNTIME"
	clashrestart
	_okcat "已切换到规则模式"
	clashctl tun
}

clashg() {
	sudo $BIN_YQ -i '.mode = "global"' "$CLASH_CONFIG_RUNTIME"
	clashrestart
	_okcat "已切换到全局模式"
	clashctl tun
}

clasht() {
	if clashctl tun 2>&1 | grep -q "关闭"; then
		clashctl tun on
	elif clashctl tun 2>&1 | grep -q "启用"; then
		clashctl tun off
	else
		clashctl tun
	fi
}

clashctl_patch
alias clash="clashctl proxy"
EOF
	)
	
	remove_shell_rc_sub_block "clashctl patch" "$rc_file"
    log "INFO" "Patching clashctl into shell rc file: $rc_file"
	append_shell_rc_sub_block "clashctl patch" "$content" "$rc_file"
}

_init_clashctl_post_install_callback() {
	_clashctl_shell_patch $(get_rc_file zsh)
	_clashctl_shell_patch $(get_rc_file bash)
}
