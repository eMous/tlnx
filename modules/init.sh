#!/bin/bash

# init module - system bootstrap configuration

_init_check_installed() {
	return 1
}

# Module entrypoint - init
_init_install() {
	local subprocedures=("init_symbolic_link" "init_shell" "init_network_info"
		"init_check_internet_access" "init_enable_bbr" "init_update_aliyun_mirror"
		"init_timezone" "init_timesyncd" "init_ssh_keys")


	for subproc in "${subprocedures[@]}"; do
		local func="${subproc}"
		log "INFO" "<<<< Subprocedure Running: $func"
		"$func"
		if [ $? -ne 0 ]; then
			log "ERROR" ">>>> Subprocedure $func failed"
			return 1
		else
			log "INFO" ">>>> Subprocedure $func completed successfully"
		fi
	done

	# rewrite _init_check_installed to return 0
	_init_check_installed() {
		return 0
	}
}

init_symbolic_link() {
	log "INFO" "Creating symbolic links for configuration files..."
	local src_base="$TLNX_DIR/etc/.config"
	local dest_base="$HOME/.config"

	if [ ! -d "$src_base" ]; then
		log "ERROR" "Source configuration directory $src_base does not exist; skipping symbolic links."
		exit 1
	fi

	mkdir -p "$dest_base"

	# Enable dotglob to include hidden files
	shopt -s dotglob
	for src_path in "$src_base"/*; do
		[ -e "$src_path" ] || continue

		local item_name
		item_name=$(basename "$src_path")
		local dest_path="$dest_base/$item_name"

		# Check if destination exists
		if [ -e "$dest_path" ] || [ -L "$dest_path" ]; then
			# Check if it's already a symlink to the correct location
			if [ -L "$dest_path" ]; then
				local current_target
				current_target=$(readlink -f "$dest_path")
				local expected_target
				expected_target=$(readlink -f "$src_path")
				
				if [ "$current_target" = "$expected_target" ]; then
					log "DEBUG" "$dest_path is already linked to $src_path; skipping"
					continue
				fi
			fi

			# Backup existing file/dir/link
			local backup_path="${dest_path}.bak-$(date +%Y%m%d%H%M%S)"
			log "INFO" "Backing up existing $dest_path to $backup_path"
			mv "$dest_path" "$backup_path"
		fi

		# Create symlink
		ln -s "$src_path" "$dest_path"
		log "INFO" "Linked $src_path to $dest_path"
	done
	shopt -u dotglob
}

init_shell() {
	local curshell="$(get_current_shell)"
	
	# Bash setup
	local bashrc="$HOME/.bashrc"
	touch "$bashrc"
	local bash_content=$(cat <<EOF
export PATH="$TLNX_DIR:\$HOME/.local/bin:\$PATH"
if [ -f "\$HOME/.config/bash/.bashrc" ]; then
    source "\$HOME/.config/bash/.bashrc"
fi
EOF
)
	local current_bashrc_content=$(cat "$bashrc")
	if [[ "$current_bashrc_content" != *"$bash_content"* ]]; then
		remove_shell_rc_sub_block "init_bash" "$bashrc"
		append_shell_rc_sub_block "init_bash" "$bash_content" "$bashrc"
		log "INFO" "Configured bashrc at $bashrc"
	else
		log "INFO" "bashrc already configured at $bashrc, skipping"
	fi
	export BDOTDIR="$TLNX_DIR/etc/.config/bash"


	# install zsh
	if ! command -v zsh >/dev/null 2>&1; then
		log "INFO" "zsh not found, installing..."
		# Install ZSH
		sudo apt-get install -y zsh 2>&1 | tee -a "$LOG_FILE"
		if [ ${PIPESTATUS[0]} -ne 0 ]; then
			log "ERROR" "ZSH installation failed"
			return 1
		else
			log "INFO" "ZSH installed successfully"
		fi
	else
		log "INFO" "ZSH is already installed, skipping installation"
	fi

	# set zdotdir
	touch "$HOME/.zshenv"
	local content=$(
	cat <<EOF
export ZDOTDIR="\$HOME/.config/zsh"
[[ -f "\$ZDOTDIR/.zshenv" ]] && source "\$ZDOTDIR/.zshenv"
EOF
	)
	export ZDOTDIR="$HOME/.config/zsh"
	# if content exists in .zshenv, skip
	if [[ "$(cat $HOME/.zshenv)" != *"$content"* ]]; then
		remove_shell_rc_sub_block "zshenv zdotdir config" "$HOME/.zshenv"
		append_shell_rc_sub_block "zshenv zdotdir config" "$content" "$HOME/.zshenv"
		log "INFO" "ZDOTDIR configured to \$HOME/.config/zsh"
	else
		log "INFO" "ZDOTDIR already configured in $HOME/.zshenv, skipping"
	fi

	# Leave $HOME/.zshrc as is, use the one in $TLNX_DIR/etc/.config/zsh/.zshrc 
	# and in $TLNX_DIR/etc/.config/zsh/.zshrc it sources the $HOME/.zshrc
	touch "$HOME/.zshrc"

	# Set default shell to zsh
	local default_shell="$(get_default_shell)"
	if [ "$(basename "$default_shell")" != "zsh" ]; then	
		log "INFO" "Setting ZSH as the default shell..."
		# Determine current user
		local current_user=$(whoami)
		# Update default shell for the user
		local user=$(whoami)
		command sudo chsh -s "$(which zsh)" "$user" 2>&1 | tee -a "$LOG_FILE"
	else
		log "INFO" "Default shell is already ZSH; skipping default shell change"
	fi
	return 0
}

# Update Alibaba Cloud mirrors
init_update_aliyun_mirror() {
	log "INFO" "Updating Alibaba Cloud package mirrors. Detected system: $DISTRO_NAME $DISTRO_VERSION"

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
		if grep -q "^# Managed by TLNX" /etc/apt/sources.list 2>/dev/null; then
			log "INFO" "Apt sources already configured for Alibaba Cloud; skipping"
		else
			local arm=$(uname -m | grep -qE '^arm|^aarch64' && echo "-ports/" || echo "/")
			sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
			command sudo tee /etc/apt/sources.list >/dev/null <<EOF
# Managed by TLNX
deb http://mirrors.aliyun.com/ubuntu${arm} ${UBUNTU_CODENAME} main restricted universe multiverse
#deb-src http://mirrors.aliyun.com/ubuntu${arm} ${UBUNTU_CODENAME} main restricted universe multiverse

deb http://mirrors.aliyun.com/ubuntu${arm} ${UBUNTU_CODENAME}-security main restricted universe multiverse
#deb-src http://mirrors.aliyun.com/ubuntu${arm} ${UBUNTU_CODENAME}-security main restricted universe multiverse

deb http://mirrors.aliyun.com/ubuntu${arm} ${UBUNTU_CODENAME}-updates main restricted universe multiverse
#deb-src http://mirrors.aliyun.com/ubuntu${arm} ${UBUNTU_CODENAME}-updates main restricted universe multiverse

deb http://mirrors.aliyun.com/ubuntu${arm} ${UBUNTU_CODENAME}-proposed main restricted universe multiverse
#deb-src http://mirrors.aliyun.com/ubuntu${arm} ${UBUNTU_CODENAME}-proposed main restricted universe multiverse

deb http://mirrors.aliyun.com/ubuntu${arm} ${UBUNTU_CODENAME}-backports main restricted universe multiverse
#deb-src http://mirrors.aliyun.com/ubuntu${arm} ${UBUNTU_CODENAME}-backports main restricted universe multiverse
EOF
		fi
		# if there is any file in /etc/apt/sources.list.d/ not end with .bak, mv it to .bak
		for file in /etc/apt/sources.list.d/*; do
			if [ -f "$file" ] && [[ ! "$file" =~ \.bak$ ]]; then
				log "INFO" "Backing up $file to $file.bak"
				sudo mv "$file" "$file.bak"
			fi
		done
		
		local need_update=false
		if ! mark_exists "init_update_aliyun_mirror"; then
			need_update=true
		else
			local last_update_file="/var/lib/apt/periodic/update-success-stamp"
			if [ -f "$last_update_file" ]; then
				local last_update_time=$(stat -c %Y "$last_update_file")
				local current_time=$(date +%s)
				local diff=$((current_time - last_update_time))
				if [ $diff -gt 1200 ]; then # 20 minutes = 1200 seconds
					log "INFO" "Last apt update was more than 20 minutes (1200 seconds) ago ($diff seconds), updating..."
					need_update=true
				else
					log "INFO" "Last apt update was less than 20 minutes (1200 seconds) ago ($diff seconds), skipping update"
				fi
			else
				log "INFO" "No apt update timestamp found, updating..."
				need_update=true
			fi
		fi

		if [ "$need_update" = "true" ]; then
			local current_timestamp=$(date +"%Y%m%d%H%M%S")
			sudo apt-get update -y 2>&1 | tee -a "$LOG_FILE" >/dev/null
			local apt_status=${PIPESTATUS[0]}
			if [ $apt_status -ne 0 ]; then
				log "ERROR" "Failed to update apt package lists after changing mirrors"
				return 1
			fi
			mark_exists "init_update_aliyun_mirror" || add_mark "init_update_aliyun_mirror"
		fi
	else
		log "WARN" "Unsupported distribution $DISTRO_NAME, skipping mirror update"
	fi
	log "INFO" "Finished updating Alibaba Cloud mirrors"
}

# Make sure the project directory is or will be in /opt/tlnx
init_prjdir() {
	# It seems there is no need to mv the prjdir to /opt/tlnx explicity
	return 0
	log "INFO" "Checking project directory..."
	local old_project_dir="$TLNX_DIR"
	if [ -z "$TLNX_DIR" ]; then
		log "ERROR" "TLNX_DIR is not set. Cannot continue."
		return 1
	fi
	if [ "$TLNX_DIR" = "/opt/tlnx" ]; then
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
	sudo rsync -ar "$TLNX_DIR"/* /opt/tlnx/ 2>&1 | tee -a "$LOG_FILE"
	local rsync_status=${PIPESTATUS[0]}
	if [ $rsync_status -ne 0 ]; then
		log "ERROR" "Failed to rsync project files to /opt/tlnx"
		return 1
	fi
	#rm -rf "$TLNX_DIR"

	# LOG_FILE update to: in original LOG_FILE, the $TLNX_DIR substituted to /opt/tlnx
	LOG_FILE="${LOG_FILE//$TLNX_DIR/\/opt\/tlnx}"
	log "INFO" "Log file path updated to $LOG_FILE"
	TLNX_DIR="/opt/tlnx"
	log "INFO" "Project directory set to /opt/tlnx"

	# if old_project_dir is not TLNX_DIR, empty file STALE.md in TLNX_DIR
	if [ "$old_project_dir" != "$TLNX_DIR" ]; then
		log "INFO" "Project directory has changed from $old_project_dir to $TLNX_DIR"
		: >$old_project_dir/STALE.md
		echo "This project directory has been moved to $TLNX_DIR on $(date). So the dir: $old_project_dir is STALE to use!" >>$old_project_dir/STALE.md
		chmod 777 $old_project_dir/STALE.md
	else
		log "INFO" "Project directory remains unchanged"
	fi

	return 0
}

# Internet Access Check
init_check_internet_access() {
	log "INFO" "Checking internet access"

	# Checking http(s) proxy, if http proxy is empty
	source_rcfile $HOME/.bashrc >/dev/null 

	if [ -z "$http_proxy" ]; then
		log "WARN" "No HTTP proxy detected."
	else
		log "INFO" "HTTP proxy detected: $http_proxy"
	fi

	if [ -z "$https_proxy" ]; then
		log "WARN" "No HTTPS proxy detected."
	else
		log "INFO" "HTTPS proxy detected: $https_proxy"
	fi

	# if set CONTINUE_WITHOUT_INTERNET=1, skip the check
	if [ "${CONTINUE_WITHOUT_INTERNET:-n}" = "y" ]; then
		log "INFO" "CONTINUE_WITHOUT_INTERNET is set; skipping internet access check"
		return 0
	fi
	log "INFO" "Performing internet access check by connecting to https://www.google.com ..."
	curl --max-time 5 -I https://www.google.com >/dev/null 2> >(tee -a "$LOG_FILE")

	local CURL_STATUS=${PIPESTATUS[0]}
	if [ $CURL_STATUS -ne 0 ]; then
		log "WARN" "Google access check failed, please use --set-proxy to set a working HTTP proxy"

		# Choose force continue or input a proxy
		log "INFO" "You can choose to continue without internet access (some modules may fail) or set a proxy and retry"
		while true; do
			local yn=${CONTINUE_WITHOUT_INTERNET:-}
			if [ -n "$yn" ]; then
				log "INFO" "Using predefined choice for continuing without internet: $yn"
			else
				read -rp "Do you want to continue without internet access? (y/n): " yn
			fi
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
	log "INFO" "Check enabling BBR congestion control"

	# Check if BBR is already enabled
	local CURRENT_CONGESTION
	CURRENT_CONGESTION=$(sysctl net.ipv4.tcp_congestion_control | awk '{print $3}')

	if [ "$CURRENT_CONGESTION" = "bbr" ]; then
		log "INFO" "BBR is already enabled"
		return 0
	fi

	# Enable BBR
	sudo modprobe tcp_bbr
	echo "tcp_bbr" | command sudo tee -a /etc/modules-load.d/bbr.conf
	sudo sysctl -w net.core.default_qdisc=fq
	sudo sysctl -w net.ipv4.tcp_congestion_control=bbr

	# Persist settings
	echo "net.core.default_qdisc=fq" | command sudo tee -a /etc/sysctl.d/99-bbr.conf
	echo "net.ipv4.tcp_congestion_control=bbr" | command sudo tee -a /etc/sysctl.d/99-bbr.conf
	sudo sysctl -p /etc/sysctl.d/99-bbr.conf
	log "INFO" "BBR congestion control enabled"
}

init_timezone() {
	# if current timezone is not Asia/Shanghai, set it
	local CURRENT_TZ
	CURRENT_TZ=$(timedatectl | grep "Time zone" | awk '{print $3}')
	if [ "$CURRENT_TZ" = "Asia/Shanghai" ]; then
		log "INFO" "Timezone is already set to Asia/Shanghai"
		return 0
	fi
	log "INFO" "Setting system timezone to Asia/Shanghai"
	sudo timedatectl set-timezone Asia/Shanghai
	log "INFO" "System timezone set to $(timedatectl | grep 'Time zone')"
}
init_timesyncd() {
	# Check if systemd-timesyncd is installed
	if ! command -v timedatectl >/dev/null 2>&1; then
		log "INFO" "timesyncd is not installed, installing..."
		# sudo apt-get update -y 2>&1 | tee -a "$LOG_FILE"
		sudo apt-get install -y systemd-timesyncd 2>&1 | tee -a "$LOG_FILE"
		local install_status=${PIPESTATUS[0]}
		if [ $install_status -ne 0 ]; then
			log "ERROR" "Failed to install systemd-timesyncd"
			return 1
		fi
		log "INFO" "systemd-timesyncd installed successfully"
	else
		log "INFO" "systemd-timesyncd is already installed, skipping..."
	fi

	# configure ntp servers: ntp.aliyun.com ntp1.aliyun.com ntp2.aliyun.com
	local timesyncd_conf="/etc/systemd/timesyncd.conf"
	if [ -f "$timesyncd_conf" ] && grep -Fq "NTP=ntp.aliyun.com ntp.hust.edu.cn" "$timesyncd_conf"; then
		log "INFO" "systemd-timesyncd already configured with Aliyun NTP servers"
	else
		sudo tee /etc/systemd/timesyncd.conf >/dev/null <<EOF
[Time]
NTP=ntp.aliyun.com ntp.hust.edu.cn
FallbackNTP=ntp1.aliyun.com ubuntu.pool.ntp.org
EOF
		sudo systemctl restart systemd-timesyncd 2>&1 | tee -a "$LOG_FILE"
		local restart_status=${PIPESTATUS[0]}
		if [ $restart_status -ne 0 ]; then
			log "ERROR" "Failed to restart systemd-timesyncd"
			return 1
		fi
		sudo systemctl enable systemd-timesyncd 2>&1 | tee -a "$LOG_FILE"
		log "INFO" "systemd-timesyncd configured with Aliyun NTP servers"
	fi
	log "INFO" "Current system time: $(date)"
	log "INFO" "Current clock synchronization status: $(timedatectl status | grep 'System clock synchronized' | awk '{print $4}')"
	return 0
}

init_network_info() {
	local wanipv4
	# Get WAN IP by Curl unset http_proxy
	wanipv4=$(http_proxy= curl -s https://api-ipv4.ip.sb/ip | xargs)
	if [ -z "$wanipv4" ]; then
		log "ERROR" "Failed to retrieve WAN IPv4 address"
	else
		log "INFO" "Retrieved WAN IPv4 address: $wanipv4"
	fi

	local wanipv6
	# curl without http_proxy
	wanipv6=$(http_proxy= curl -s https://api-ipv6.ip.sb/ip | xargs)
	if [ -z "$wanipv6" ]; then
		log "ERROR" "Failed to retrieve WAN IPv6 address"
	else
		log "INFO" "Retrieved WAN IPv6 address: $wanipv6"
	fi

	# Get lan ip
	local lanip
	# trim lan ip spaces
	lanip=$(hostname -I | xargs)
	if [ -z "$lanip" ]; then
		log "ERROR" "Failed to retrieve LAN IP address"
	else
		log "INFO" "Retrieved LAN IP address: $lanip"
	fi

	# Skip hostname changes inside docker test containers; they fail due to bind-mounted /etc/hostname.
	if [ "${TLNX_DOCKER_CHILD:-0}" = "1" ]; then
		log "INFO" "Docker test container detected; skipping hostnamectl/hostname changes"
	else
		# If the mark of set-hostname not exist in mark.log, set hostname
		sudo -u $(whoami) mkdir -p "$TLNX_DIR/run"
		if mark_exists "init_set_hostname"; then
			log "INFO" "Mark init_set_hostname found. Hostname has already been set previously; skipping"
			return 0
		fi
		# Ask user to set hostname or keep current
		local current_hostname
		current_hostname=$(hostname)
		log "INFO" "Current hostname is: $current_hostname"
		local new_hostname
		if [ -n "$INIT_HOSTNAME" ]; then
			new_hostname="$INIT_HOSTNAME"
			log "INFO" "Using configured hostname: $new_hostname"
		else
			read -rp "Enter new hostname (leave empty to keep '$current_hostname'): " input_hostname
			if [ -n "$input_hostname" ]; then
				new_hostname="$input_hostname"
			else
				new_hostname="$current_hostname"
			fi
		fi
		
		if [ "$current_hostname" != "$new_hostname" ]; then
			sudo hostnamectl set-hostname "$new_hostname"
			sudo sed -i "s/$current_hostname/$new_hostname/g" /etc/hosts
			log "INFO" "Hostname set to: $new_hostname"
		else
			log "INFO" "Hostname is already set to $new_hostname; skipping"
		fi
		mark_exists "init_set_hostname" || add_mark "init_set_hostname"
	fi

	# add WAN and LAN IP to run/info
	local INFO_FILE="$TLNX_DIR/run/info"
	mkdir -p "$(dirname "$INFO_FILE")"
	if [ ! -f "$INFO_FILE" ]; then
		touch "$INFO_FILE"
	fi
	# If there is any existing WAN_IPv4, WAN_IPv6, LAN_IP in INFO_FILE, substitute it
	if grep -q "^WAN_IPv4=" "$INFO_FILE"; then
		sed -i "s/^WAN_IPv4=.*/WAN_IPv4=\"$wanipv4\"/" "$INFO_FILE"
	else
		echo "WAN_IPv4=\"$wanipv4\"" >>"$INFO_FILE"
	fi

	if grep -q "^WAN_IPv6=" "$INFO_FILE"; then
		sed -i "s/^WAN_IPv6=.*/WAN_IPv6=\"$wanipv6\"/" "$INFO_FILE"
	else
		echo "WAN_IPv6=\"$wanipv6\"" >>"$INFO_FILE"
	fi

	if grep -q "^LAN_IP=" "$INFO_FILE"; then
		sed -i "s/^LAN_IP=.*/LAN_IP=\"$lanip\"/" "$INFO_FILE"
	else
		echo "LAN_IP=\"$lanip\"" >>"$INFO_FILE"
	fi
	log "INFO" "Network info updated in $INFO_FILE"
	return 0
}

# SSH Key setup
init_ssh_keys() {
	log "INFO" "Checking SSH key setup"
	# if mark of key pairs exist in $TLNX_DIR/run/keys, skip
	local keydir="$TLNX_DIR/run/keys"
	mkdir -p "$keydir"
	local keyname="id_rsa-$(whoami)@$(hostname)"
	if [ -f "$keydir/$keyname" ] && [ -f "$keydir/$keyname.pub" ]; then
		log "INFO" "SSH key pair already exists, skipping generation"
		return 0
	fi
	log "INFO" "Generating new SSH key pair"
	ssh-keygen -t rsa -b 4096 -f "$keydir/$keyname" -N "" 2>&1  #| tee -a "$LOG_FILE"
	local ssh_status=${PIPESTATUS[0]}
	if [ $ssh_status -ne 0 ]; then
		log "ERROR" "Failed to generate SSH key pair"
		return 1
	fi
	log "INFO" "SSH key pair generated successfully"
	# Register it to authorized_keys
	mkdir -p "$HOME/.ssh"
	cat "$keydir/$keyname.pub" >>"$HOME/.ssh/authorized_keys"
	chmod 600 "$HOME/.ssh/authorized_keys"
	log "INFO" "SSH public key added to authorized_keys"
	return 0
}
