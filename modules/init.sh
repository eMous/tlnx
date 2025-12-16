#!/bin/bash

# init module - system bootstrap configuration
# Module entrypoint - init
_init_install() {
	local subprocedures=("init_copy_conffiles" "init_shell" "init_network_info"
		"init_check_internet_access" "init_enable_bbr" "init_update_aliyun_mirror"
		"init_timezone" "init_timesyncd" "init_ssh_keys")
	local off_mark_control=("init_shell" "init_copy_conffiles")

	log "INFO" "=== Starting init module ==="

	for subproc in "${subprocedures[@]}"; do
		local func="${subproc}"
		local mark="${subproc}_done"
		log "INFO" "Running subprocedure: $func"
		# if subproc is in off_mark_control, skip mark check
		if [[ " ${off_mark_control[*]} " == *" ${subproc} "* ]]; then
			log "INFO" "Skipping mark check for subprocedure: $func"
		else
			if mark_exists "$mark" "$PROJECT_DIR/run/marks"; then
				log "INFO" "Mark exists for subprocedure: $func; skipping"
				continue
			fi
		fi
		"$func"
		if [ $? -ne 0 ]; then
			log "ERROR" "Subprocedure $func failed"
			return 1
		else
			log "INFO" "Subprocedure $func completed successfully"
			# add mark for subproc except those in off_mark_control
			if [[ ! " ${off_mark_control[*]} " == *" ${subproc} "* ]]; then
				add_mark "$mark" "$PROJECT_DIR/run/marks"
			fi
		fi
	done

	log "INFO" "=== init module completed ==="
}

init_copy_conffiles() {
	local module
	for module in ${MODULES_TO_EXECUTE[@]}; do
		# if [ "$module" = "zsh" ] || [ "$module" = "bash" ]; then
		# 	continue
		# fi
		# if there is a dir get_config_dir $module
		local m_conf_dir=$(get_config_dir $module)
		if [ -d "$m_conf_dir" ]; then
			log "VERBOSE" "dir $m_conf_dir exist for module: $module"
			rsync -a --mkpath "$m_conf_dir/" "$HOME/.config/$module/" 2>&1 >>"$LOG_FILE"
			log "INFO" "Copied config files for module: $module"
		fi
	done
}
init_shell() {
	local curshell="$(get_current_shell)"
	local shells=("bash" "zsh")
	for shell in "${shells[@]}"; do
		# Check etc/rc file exist
		local homercpath=$HOME/$(basename $(get_rc_file "$shell"))
		touch $homercpath
		local subrcdir="$HOME/.config/$shell"
		local subrcpath=$subrcdir/$(basename $homercpath)
		local templatedir="$(get_config_dir $shell)"
		local templatepath="$templatedir/$(basename $homercpath)"
		local mark="init_shell_${shell}_done"
		mkdir -p "$subrcdir"
		if [ ! -f "$templatepath" ]; then
			log "ERROR" "Template rc file for $shell not found at $templatepath; cannot initialize"
			exit 1
		fi
		# Only bash needs to redirect in home.rc file, since zdotdir has set in .zshenv
		if [ $shell = "bash" ]; then
			log "VERBOSE" "Initilizing rc file for $shell: $homercpath"
			append_shell_rc_block "source \$HOME/.config/$shell/$(basename "$homercpath")" "$homercpath"
			log "INFO" "$homercpath initialized to source TLNX shell config"
		fi

		# PATH setup
		local content_to_check="export PATH=\"$PROJECT_DIR:\$HOME/.local/bin:\$PATH\""
		mkdir -p "$HOME/.local/bin"
		if grep -Fq "$content_to_check" "$subrcpath" 2>/dev/null; then
			log "INFO" "Project directory $PROJECT_DIR already present in $shell PATH via $subrcpath"
			continue
		fi
		log "INFO" "Adding project directory $PROJECT_DIR to $shell PATH via $subrcpath"
		export PATH="$PROJECT_DIR:$HOME/.local/bin:$PATH"
		append_shell_rc_block "$content_to_check" "$subrcpath"

		# # if shell is current running shell source the rc file
		# if [[ "$curshell" == *"$shell"* ]]; then
		# 	log "INFO" "Current shell $curshell matches $shell; sourcing rc file"
		# 	source "$homercpath"
		# fi
	done

	rsync -a $(get_config_dir "commonshell")/ "$HOME/.config/commonshell/" 2>&1 | tee -a "$LOG_FILE"
	log "INFO" "Copied TLNX commonshell config template to $HOME/.config/commonshell"
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

# Make sure the project directory is or will be in /opt/tlnx
init_prjdir() {
	# It seems there is no need to mv the prjdir to /opt/tlnx explicity
	return 0
	log "INFO" "Checking project directory..."
	local old_project_dir="$PROJECT_DIR"
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
	sudo rsync -ar "$PROJECT_DIR"/* /opt/tlnx/ 2>&1 | tee -a "$LOG_FILE"
	local rsync_status=${PIPESTATUS[0]}
	if [ $rsync_status -ne 0 ]; then
		log "ERROR" "Failed to rsync project files to /opt/tlnx"
		return 1
	fi
	#rm -rf "$PROJECT_DIR"

	# LOG_FILE update to: in original LOG_FILE, the $PROJECT_DIR substituted to /opt/tlnx
	LOG_FILE="${LOG_FILE//$PROJECT_DIR/\/opt\/tlnx}"
	log "INFO" "Log file path updated to $LOG_FILE"
	PROJECT_DIR="/opt/tlnx"
	log "INFO" "Project directory set to /opt/tlnx"

	# if old_project_dir is not PROJECT_DIR, empty file STALE.md in PROJECT_DIR
	if [ "$old_project_dir" != "$PROJECT_DIR" ]; then
		log "INFO" "Project directory has changed from $old_project_dir to $PROJECT_DIR"
		: >$old_project_dir/STALE.md
		echo "This project directory has been moved to $PROJECT_DIR on $(date). So the dir: $old_project_dir is STALE to use!" >>$old_project_dir/STALE.md
		chmod 777 $old_project_dir/STALE.md
	else
		log "INFO" "Project directory remains unchanged"
	fi

	return 0
}

# Check tlnx in bin: Add $PROJECT_DIR to PATH in rc file
init_tlnx_in_path() {
	# integreted in init_shell now
	return 0
}

# Internet Access Check
init_check_internet_access() {
	log "INFO" "Checking internet access"

	if mark_exists "internet-access-check" "$PROJECT_DIR/run/marks"; then
		log "INFO" "Internet access check already performed previously; skipping"
		return 0
	fi
	add_mark "internet-access-check" "$PROJECT_DIR/run/marks"

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
		log "INFO" "systemd-timesyncd is already installed"
	fi

	# configure ntp servers: ntp.aliyun.com ntp1.aliyun.com ntp2.aliyun.com
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
		sudo -u $(whoami) mkdir -p "$PROJECT_DIR/run"
		MARK_FILE="$PROJECT_DIR/run/marks"
		touch "$MARK_FILE"
		local mark="hostname-set"
		log "INFO" "Checking hostname setup mark in $MARK_FILE"
		if ! grep -q "$mark" "$MARK_FILE"; then
			log "INFO" "Hostname setup mark not found, proceeding to set hostname"
			# Ask user to set hostname or keep current
			local current_hostname
			current_hostname=$(hostname)
			log "INFO" "Current hostname is: $current_hostname"
			local new_hostname
			if [ -z "$INIT_HOSTNAME" ]; then
				read -rp "Do you want to change the hostname? (y/n): " change_hostname
				if [[ "$change_hostname" =~ ^[Yy]$ ]]; then
					read -rp "Enter new hostname: " new_hostname
					if [ -z "$new_hostname" ]; then
						new_hostname="$current_hostname"
						log "WARN" "No hostname entered, keeping current hostname: $current_hostname"
					fi
				else
					new_hostname="$current_hostname"
					log "INFO" "Keeping current hostname: $current_hostname"
				fi
			else
				new_hostname="$INIT_HOSTNAME"
				log "INFO" "Using configured hostname: $new_hostname"
			fi
			sudo hostnamectl set-hostname "$new_hostname"
			sudo sed -i "s/$current_hostname/$new_hostname/g" /etc/hosts
			log "INFO" "Hostname set to: $new_hostname"
			# Add mark
			add_mark "$mark" "$MARK_FILE"
		else
			log "INFO" "Hostname has already been set previously, skipping"
		fi
	fi

	# add WAN and LAN IP to run/info
	local INFO_FILE="$PROJECT_DIR/run/info"
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
	# if mark of key pairs exist in $PROJECT_DIR/run/keys, skip
	local keydir="$PROJECT_DIR/run/keys"
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

# init_bash_setup() {
# 	log "INFO" "Applying basic bash shell setup"
# 	# if there is no etc/.bashrc, return 0
# 	if [ ! -f "$PROJECT_DIR/etc/.bashrc" ]; then
# 		log "INFO" "No etc/.bashrc found, skipping bash basic setup"
# 		return 0
# 	fi
# 	local mark="bash-basic-setup"
# 	# if etc/.bashrc is newer than user's .bashrc, remove the previous block first
# 	if [ "$PROJECT_DIR/etc/.bashrc" -nt "$HOME/.bashrc" ]; then
# 		log "INFO" "Updating existing bashrc block in $HOME/.bashrc, as etc/.bashrc is newer"
# 		remove_shell_rc_sub_block "bashrc template" "$HOME/.bashrc"
# 		# remove mark of bash-basic-setup in run/marks
# 		local MARK_FILE="$PROJECT_DIR/run/marks"
# 		# remove the line of mark
# 		sed -i "/^${mark}.*$/d" "$MARK_FILE"
# 	fi

# 	# if there is a mark of bash-basic-setup in run/marks
# 	# AND the etc/.bashrc is older than marks
# 	# AND etc/.bashrc is matched in $HOME/.bashrc, skip
# 	local MARK_FILE="$PROJECT_DIR/run/marks"
# 	if grep -q "${mark}" "$MARK_FILE" && [ "$MARK_FILE" -nt "$PROJECT_DIR/etc/.bashrc" ] && grep -qFf "$PROJECT_DIR/etc/.bashrc" "$HOME/.bashrc"; then
# 		log "INFO" "Bash basic setup already applied, skipping"
# 		return 0
# 	fi
# 	# copy the contents of etc/.bashrc to user's .bashrc using append_shell_rc_sub_block
# 	append_shell_rc_sub_block "bashrc template" "$(cat $PROJECT_DIR/etc/.bashrc)" "$HOME/.bashrc"
# 	# add mark
# 	add_mark "$mark" "$MARK_FILE"
# 	log "INFO" "Basic bash shell setup applied"
# 	return 0
# }
