#!/bin/bash

# FRP module - install and configure frpc

FRP_VERSION="0.58.1"

_frp_installed_check() {
    if mark_older_than "frp_installed_mark" "$(stat -c %Y "$PROJECT_DIR/etc/HOME/.conf/frp/frpc.toml")" || mark_older_than "frp_installed_mark" "$(stat -c %Y "$PROJECT_DIR/etc/HOME/.conf/frp/frps.toml")"; then
        log "INFO" "FRP module config files modified since last run; module will run"
        # remove the mark
        sed -i "/^frp_installed_mark.*$/d" "$PROJECT_DIR/run/marks"
        return 1
    else
        log "DEBUG" "FRP module already applied (mark found)"
        return 0
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
			log "INFO" "$service_file already exists; current contents:"
			cat "$service_file" | tee -a "$LOG_FILE"
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
    local package_name="frp"
    if ! checkout_package_file "$package_name"; then
        log "ERROR" "Failed to checkout package file for $package_name"
        return 1
    fi

    local extracted_dir="$PROJECT_DIR/run/packages/$package_name"

    local arch
    arch=$(uname -m)
    local bin_dir
    case "$arch" in
        x86_64) bin_dir="amd64" ;;
        aarch64) bin_dir="arm64" ;;
        *)
            log "ERROR" "Unsupported architecture: $arch"
            return 1
            ;;
    esac

    local frpc_binary="$bin_dir/frpc"
    local frps_binary="$bin_dir/frps"

    if [ ! -f "$extracted_dir/$frpc_binary" ]; then
         log "ERROR" "Binary not found: $extracted_dir/$frpc_binary"
         return 1
    fi

    copy_to_binary "$extracted_dir/$frpc_binary" || return 1
    copy_to_binary "$extracted_dir/$frps_binary" || return 1

    local etcdir=$(get_config_dir "frp")
    if [ ! -d "$etcdir" ]; then
        log "ERROR" "No predefined FRP config directory found at $etcdir"
    else
        if [ -f "$etcdir/frpc.toml" ]; then
            copy_to_config "$etcdir/frpc.toml" "frp" || return 1
        fi
        if [ -f "$etcdir/frps.toml" ]; then
            copy_to_config "$etcdir/frps.toml" "frp" || return 1
        fi
    fi
}
_frp_install() {
    log "INFO" "=== Starting FRP module ==="
    frp_install || return 1
    frp_configure || return 1
    log "INFO" "=== FRP module completed ==="
}


# TODO  结合default.conf 或 enc.conf 完成 frp.toml的模板解析
