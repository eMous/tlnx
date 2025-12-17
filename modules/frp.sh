#!/bin/bash

# FRP module - install and configure frpc

_frp_installed_check() {
	if command -v frpc >/dev/null 2>&1 && command -v frps >/dev/null 2>&1 &&\
	[ -f /etc/systemd/system/frpc.service ] &&\
	 [ -f /etc/systemd/system/frps.service ]; then
        return 0
    else
        return 1
    fi
}

frp_configure() {
	log "VERBOSE" "Stopping any existing frpc/frps services..."
	sudo systemctl disable frpc 2>/dev/null || true
	sudo systemctl stop frpc 2>/dev/null || true
	sudo systemctl disable frps 2>/dev/null || true
	sudo systemctl stop frps 2>/dev/null || true

	log "VERBOSE" "Configuring FRP services..."
	local config_files=()
	local frpc_config_file
	frpc_config_file="$(get_config_dir "frp")/frpc.toml"
	if [ -f "$frpc_config_file" ] && [ -s "$frpc_config_file" ]; then
		log "VERBOSE" "Found FRP client configuration file $frpc_config_file"
		config_files+=("$frpc_config_file")
	fi

	local frps_config_file
	frps_config_file="$(get_config_dir "frp")/frps.toml"
	if [ -f "$frps_config_file" ] && [ -s "$frps_config_file" ]; then
		log "VERBOSE" "Found FRP server configuration file $frps_config_file"
		config_files+=("$frps_config_file")
	fi

	if [ ${#config_files[@]} -eq 0 ]; then
		log "WARN" "No FRP configuration files discovered; skipping service setup"
		return 0
	fi

	for config_file in "${config_files[@]}"; do
		local command
		command=$(basename "$config_file" .toml)
		local binary_path
		binary_path=$(command -v "$command" || true)
		if [ -z "$binary_path" ]; then
			log "ERROR" "Binary $command not found in PATH; skipping service creation"
			continue
		fi

		log "VERBOSE" "Validating FRP configuration file $config_file with $binary_path"
		if ! "$binary_path" verify -c "$config_file" >>"$LOG_FILE" 2>&1; then
			log "ERROR" "FRP configuration file $config_file is invalid; skipping $command service"
			continue
		fi

		log "INFO" "$command configuration $config_file is valid"
		log "INFO" "Setting up systemd service for $command"
		local service_file="/etc/systemd/system/${command}.service"
		if [ -f "$service_file" ]; then
			log "WARN" "$service_file already exists; Check content in log file.."
			cat "$service_file" >> "$LOG_FILE" 2>&1
			continue
		fi

		get_service_content "$config_file" "$binary_path" | command sudo tee "$service_file" >/dev/null
		sudo systemctl daemon-reload

		local varname="${command^^}_AUTO_START"
		if [ "${!varname:-false}" = "true" ]; then
			sudo systemctl restart "$command"
			sudo systemctl enable "$command"
			log "INFO" "$command service enabled and running"
		else
			log "INFO" "$varname is not true; registered $command service but left it disabled"
		fi
	done
}

get_service_content() {
	local config_file=$1
	local binary_path=$2
	local command
	command=$(basename "$config_file" .toml)
	cat <<EOF
[Unit]
Description=${command^} Service
After=network.target

[Service]
Type=simple
User=root
Restart=on-failure
RestartSec=5s
ExecStart=$binary_path -c $config_file

[Install]
WantedBy=multi-user.target
EOF
}

frp_install() {
    install_package_binary "frp" "frpc"
    install_package_binary "frp" "frps"
}
_frp_install() {
    log "INFO" "=== Starting FRP module ==="
    frp_install || return 1
    frp_configure || return 1
    log "INFO" "=== FRP module completed ==="
}


# TODO  结合default.conf 或 enc.conf 完成 frp.toml的模板解析
