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
	local config_file="/etc/frp/frpc.toml"
	
	if [ -f "$config_file" ]; then
		log "INFO" "$config_file already exists, skipping configuration"
	else
		log "INFO" "Creating default configuration at $config_file"
		
		local server_addr="${FRP_SERVER_ADDR:-127.0.0.1}"
		local server_port="${FRP_SERVER_PORT:-7000}"
		local token="${FRP_AUTH_TOKEN:-}"
		
		cat <<EOF | sudo tee "$config_file" > /dev/null
serverAddr = "$server_addr"
serverPort = $server_port

auth.method = "token"
auth.token = "$token"

[[proxies]]
name = "ssh"
type = "tcp"
localIP = "127.0.0.1"
localPort = 22
remotePort = 6000
EOF
		log "INFO" "Configuration created. Please edit $config_file with your actual settings."
	fi
	
	# Systemd service
	local service_file="/etc/systemd/system/frpc.service"
	if [ ! -f "$service_file" ]; then
		log "INFO" "Creating systemd service..."
		cat <<EOF | sudo tee "$service_file" > /dev/null
[Unit]
Description=Frp Client Service
After=network.target

[Service]
Type=simple
User=root
Restart=on-failure
RestartSec=5s
ExecStart=/usr/local/bin/frpc -c /etc/frp/frpc.toml

[Install]
WantedBy=multi-user.target
EOF
		sudo systemctl daemon-reload
		sudo systemctl enable frpc
		log "INFO" "frpc service enabled"
	fi
}

_frp_install() {
	log "INFO" "=== Starting FRP module ==="
    local package_name="frp"
    if ! checkout_package_file "$package_name"; then
        log "ERROR" "Failed to checkout package file for $package_name"
        return 1
    fi
 
    local extracted_dir="$PROJECT_DIR/run/packages/$package_name"
    cd $extracted_dir
    local frpc_binary="frpc"
    local frps_binary="frps"


	frp_configure
    
	log "INFO" "=== FRP module completed ==="
}

_frp_uninstall() {
    log "INFO" "=== Starting FRP module uninstallation ==="
    # check if frpc service exists
    if ! systemctl list-units --full -all | grep -Fq "frps.service"; then
        log "INFO" "frps service not found; skipping uninstall frps service"
        return 0
    else 
        log "INFO" "frps service found; try to uninstall frps service"
        sudo systemctl stop frps
        sudo systemctl disable frps
        sudo rm -f /etc/systemd/system/frps.service
    fi

    if ! systemctl list-units --full -all | grep -Fq "frpc.service"; then
        log "INFO" "frpc service not found; skipping uninstall frpc service"
        return 0
    else
        log "INFO" "frpc service found; try to uninstall frpc service"
        sudo systemctl stop frpc
        sudo systemctl disable frpc
        sudo rm -f /etc/systemd/system/frpc.service
    fi

    # TODO HERE
    sudo rm -f /usr/local/bin/frpc
    sudo rm -f /usr/local/bin/frps

    sudo rm -f /etc/frp/frpc.toml
    sudo systemctl daemon-reload
    log "INFO" "FRP module uninstalled"
    log "INFO" "=== FRP module uninstallation completed ==="
}