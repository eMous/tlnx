#!/bin/bash

# FRP module - install and configure frpc

FRP_VERSION="0.58.1"

frp_check_arch() {
	local arch=$(uname -m)
	case $arch in
		x86_64)
			echo "amd64"
			;;
		aarch64)
			echo "arm64"
			;;
		*)
			log "ERROR" "Unsupported architecture: $arch"
			return 1
			;;
	esac
}

frp_install() {
	if command -v frpc >/dev/null 2>&1; then
		log "INFO" "frpc is already installed"
		return 0
	fi

	local arch
	arch=$(frp_check_arch) || return 1
	
	local filename="frp_${FRP_VERSION}_linux_${arch}"
	local url="https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/${filename}.tar.gz"
	local tmp_dir="/tmp/frp_install"
	
	log "INFO" "Downloading FRP from $url"
	mkdir -p "$tmp_dir"
	
	if curl -L "$url" -o "$tmp_dir/frp.tar.gz" 2>&1 | tee -a "$LOG_FILE"; then
		log "INFO" "Download successful"
	else
		log "ERROR" "Download failed"
		rm -rf "$tmp_dir"
		return 1
	fi
	
	log "INFO" "Extracting FRP..."
	tar -xzf "$tmp_dir/frp.tar.gz" -C "$tmp_dir"
	
	log "INFO" "Installing frpc binary..."
	sudo cp "$tmp_dir/$filename/frpc" /usr/local/bin/
	sudo chmod +x /usr/local/bin/frpc
	
	sudo mkdir -p /etc/frp
	
	# Clean up
	rm -rf "$tmp_dir"
	
	if command -v frpc >/dev/null; then
		log "INFO" "frpc installed successfully"
	else
		log "ERROR" "frpc installation failed"
		return 1
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
	frp_install
	frp_configure
	log "INFO" "=== FRP module completed ==="
}
