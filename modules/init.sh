#!/bin/bash

# init module - system bootstrap configuration

# Always run init (return 1 so the installer executes)
_init_check_installed() {
	log "DEBUG" "init module always runs to prepare the system"
	return 1
}

# Update Alibaba Cloud mirrors
init_update_aliyun_mirror() {
	log "INFO" "Updating Alibaba Cloud package mirrors"

	log "INFO" "Detected system: $DISTRO_NAME $DISTRO_VERSION"

	if [ "$DISTRO_NAME" = "ubuntu" ]; then
		log "INFO" "Ubuntu detected, switching apt sources to Alibaba Cloud"

		local UBUNTU_CODENAME=""
		if command -v lsb_release >/dev/null 2>&1; then
			UBUNTU_CODENAME=$(lsb_release -cs)
		else
			log "ERROR" "lsb_release command not found; cannot detect Ubuntu codename"
			return 1
		fi

		if [[ "$DISTRO_VERSION" == 22.* ]] || [[ "$DISTRO_VERSION" == 24.* ]]; then
			log "INFO" "Ubuntu $DISTRO_VERSION is supported"
		else
			log "WARN" "Ubuntu $DISTRO_VERSION is outside the tested range; skipping mirror update"
			return 0
		fi

		# if already using aliyun mirror, skip: check first line of sources.list contains TLNX
		if grep -q "^# Managed by TLNX" /etc/apt/sources.list; then
			log "INFO" "Apt sources already configured for Alibaba Cloud; skipping"
		else

			sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
			sudo tee /etc/apt/sources.list >/dev/null <<EOF
# Managed by TLNX
deb http://mirrors.aliyun.com/ubuntu/ ${UBUNTU_CODENAME} main restricted universe multiverse
#deb-src http://mirrors.aliyun.com/ubuntu/ ${UBUNTU_CODENAME} main restricted universe multiverse

deb http://mirrors.aliyun.com/ubuntu/ ${UBUNTU_CODENAME}-security main restricted universe multiverse
#deb-src http://mirrors.aliyun.com/ubuntu/ ${UBUNTU_CODENAME}-security main restricted universe multiverse

deb http://mirrors.aliyun.com/ubuntu/ ${UBUNTU_CODENAME}-updates main restricted universe multiverse
#deb-src http://mirrors.aliyun.com/ubuntu/ ${UBUNTU_CODENAME}-updates main restricted universe multiverse

deb http://mirrors.aliyun.com/ubuntu/ ${UBUNTU_CODENAME}-proposed main restricted universe multiverse
#deb-src http://mirrors.aliyun.com/ubuntu/ ${UBUNTU_CODENAME}-proposed main restricted universe multiverse

deb http://mirrors.aliyun.com/ubuntu/ ${UBUNTU_CODENAME}-backports main restricted universe multiverse
#deb-src http://mirrors.aliyun.com/ubuntu/ ${UBUNTU_CODENAME}-backports main restricted universe multiverse
EOF
		fi
		# if there is any file in /etc/apt/sources.list.d/ not end with .bak, mv it to .bak
		for file in /etc/apt/sources.list.d/*; do
			if [ -f "$file" ] && [[ ! "$file" =~ \.bak$ ]]; then
				log "INFO" "Backing up $file to $file.bak"
				sudo mv "$file" "$file.bak"
			fi
		done
		sudo apt-get update -y 2>&1 | tee -a "$LOG_FILE"
		local apt_status=${PIPESTATUS[0]}
		if [ $apt_status -ne 0 ]; then
			log "ERROR" "Failed cto update apt package lists after changing mirrors"
			return 1
		fi
	else
		log "WARN" "Unsupported distribution $DISTRO_NAME, skipping mirror update"
	fi
	log "INFO" "Finished updating Alibaba Cloud mirrors"
}

# Module entrypoint - init
_init_install() {

	log "INFO" "=== Starting init module ==="
	init_prjdir
	init_shell_rc_file
	init_tlnx_in_path
	init_check_internet_access
	init_enable_bbr
	init_update_aliyun_mirror

	log "INFO" "=== init module completed ==="
}

# Make sure the project directory is or will be in /opt/tlnx
init_prjdir() {
	log "INFO" "Checking project directory..."
	if [ -z "$PROJECT_DIR" ]; then
		log "ERROR" "PROJECT_DIR is not set. Cannot continue."
		return 1
	fi
	if [ "$PROJECT_DIR" = "/opt/tlnx" ]; then
		log "INFO" "Project directory is correctly set to /opt/tlnx"
		return 0
	fi
	# if /opt/tlnx exist and not empty
	if [ -d "/opt/tlnx" ] && [ "$(ls -A /opt/tlnx)" ]; then
		log "WARN" "/opt/tlnx already exists, clean the directory to continue"
		sudo mkdir -p /opt/tlnx.bak
		sudo mv /opt/tlnx /opt/tlnx.bak/"tlnx.bak."$(date +"%Y%m%d_%H%M%S")
		log "INFO" "Backup of /opt/tlnx created at /opt/tlnx.bak/"
		sudo mkdir -p /opt/tlnx
	fi

	log "INFO" "Installing project to /opt/tlnx"
	sudo mkdir -p /opt/tlnx

	# rsync  all stdout and stderr both output to log file and console
	sudo rsync -r "$PROJECT_DIR"/* /opt/tlnx/ 2>&1 | tee -a "$LOG_FILE"
	local rsync_status=${PIPESTATUS[0]}
	if [ $rsync_status -ne 0 ]; then
		log "ERROR" "Failed to rsync project files to /opt/tlnx"
		return 1
	fi
	PROJECT_DIR="/opt/tlnx"
	log "INFO" "Project directory set to /opt/tlnx"
	return 0
}

# Check tlnx in bin: TODO : ADD /opt/tlnx to PATH in rc file
init_tlnx_in_path() {
	return 0
	# log "INFO" "Checking /usr/local/bin is in PATH"
	# if ! echo "$PATH" | grep -q "/usr/local/bin"; then
	#     log "INFO" "/usr/local/bin not in PATH, adding it"
	#     export PATH="/usr/local/bin:$PATH"
	#     # add it to rc files
	#     for rc_file in "$HOME/.bashrc" "$HOME/.zshrc"; do
	#         if [ -f "$rc_file" ]; then
	#             if ! grep -q 'export PATH="/usr/local/bin:$PATH"' "$rc_file"; then
	#                 echo 'export PATH="/usr/local/bin:$PATH"' >> "$rc_file"
	#                 log "INFO" "Added /usr/local/bin to PATH in $rc_file"
	#             fi
	#         fi
	#     done
	# else
	#     log "INFO" "/usr/local/bin already in PATH"
	# fi
	# log "INFO" "Linking tlnx command to /usr/local/binx"
	# rm -f /usr/local/bin/tlnx
	# sudo ln -s "$PROJECT_DIR/tlnx" /usr/local/bin/tlnx
}

# Internet Access Check
init_check_internet_access() {
	log "INFO" "Checking internet access"
	# Checking http(s) proxy, if http proxy is empty

	source_rcfile
	if [ -z "$http_proxy" ]; then
		log "WARN" "No HTTP proxy detected, performing direct internet access check"
	else
		log "INFO" "HTTP proxy detected: $http_proxy"
	fi

	if [ -z "$https_proxy" ]; then
		log "WARN" "No HTTPS proxy detected, performing direct internet access check"
	else
		log "INFO" "HTTPS proxy detected: $https_proxy"
	fi

	curl --max-time 10 -I https://www.google.com >/dev/null 2> >(tee -a "$LOG_FILE")

	local CURL_STATUS=${PIPESTATUS[0]}
	if [ $CURL_STATUS -ne 0 ]; then
		log "WARN" "Google access check failed, please use --set-proxy to set a working HTTP proxy"

		# Choose force continue or input a proxy
		log "INFO" "You can choose to continue without internet access (some modules may fail) or set a proxy and retry"
		while true; do
			read -rp "Do you want to continue without internet access? (y/n): " yn
			case $yn in
			[Yy]*)
				log "INFO" "Continuing without internet access"
				return 0
				;;
			[Nn]*)
				read -rp "Please enter your HTTP proxy (e.g., http://proxyserver:port): " user_proxy
				export http_proxy="$user_proxy"
				export https_proxy="$user_proxy"
				log "INFO" "Retrying internet access check with provided proxy"
				curl --max-time 10 -I https://www.google.com >/dev/null 2> >(tee -a "$LOG_FILE")
				local RETRY_CURL_STATUS=${PIPESTATUS[0]}
				if [ $RETRY_CURL_STATUS -ne 0 ]; then
					log "ERROR" "Internet access check failed again with provided proxy"
					unset http_proxy
					unset https_proxy
				else
					log "INFO" "Internet access check successful with provided proxy"
					set_http_proxy "$user_proxy"
					return 0
				fi
				;;
			esac
		done
		return 1
	else
		log "INFO" "Internet access check successful"
		return 0
	fi
}

# Enable BBR congestion control
init_enable_bbr() {
	log "INFO" "Enabling BBR congestion control"

	# Check if BBR is already enabled
	local CURRENT_CONGESTION
	CURRENT_CONGESTION=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')

	if [ "$CURRENT_CONGESTION" = "bbr" ]; then
		log "INFO" "BBR is already enabled"
		return 0
	fi

	# Enable BBR
	sudo modprobe tcp_bbr
	echo "tcp_bbr" | sudo tee -a /etc/modules-load.d/bbr.conf
	sudo sysctl -w net.core.default_qdisc=fq
	sudo sysctl -w net.ipv4.tcp_congestion_control=bbr

	# Persist settings
	echo "net.core.default_qdisc=fq" | sudo tee -a /etc/sysctl.d/99-bbr.conf
	echo "net.ipv4.tcp_congestion_control=bbr" | sudo tee -a /etc/sysctl.d/99-bbr.conf
	sudo sysctl -p /etc/sysctl.d/99-bbr.conf
	log "INFO" "BBR congestion control enabled"
}

# TODO HOSTNAME setup
# TODO Timezone setup
# TODO NTP setup
# TODO ssh keys

# TODO BASH BASIC SETUP
