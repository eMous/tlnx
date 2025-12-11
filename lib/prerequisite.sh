#!/bin/bash 

_detect_prerequisites() {
	check_user || {
		log "ERROR" "User check failed. Exiting."
		return 1
	}
	check_sudo_command || {
		log "ERROR" "sudo command missing. Exiting."
		return 1
	}
	check_systemctl_command || {
		log "ERROR" "systemctl command missing. Exiting."
		return 1
	}
	check_distro || {
		log "ERROR" "Unsupported operating system distribution. Exiting."
		return 1
	}
	check_rcfile || {
		log "ERROR" "Shell RC file check failed. Exiting."
		return 1
	}
	check_aptlock || {
		log "ERROR" "APT lock check failed. Exiting."
		return 1
	}
	ensure_curl_installed || {
		log "ERROR" "curl installation check failed. Exiting."
		return 1
	}
	ensure_lsb_release_installed || {
		log "ERROR" "lsb_release installation check failed. Exiting."
		return 1
	}
	ensure_ssh_keygen_available || {
		log "ERROR" "ssh-keygen installation check failed. Exiting."
		return 1
	}
	ensure_rsync_installed || {
		log "ERROR" "rsync installation check failed. Exiting."
		return 1
	}
}

check_aptlock(){
	sudo killall apt apt-get dpkg  2>/dev/null
	sudo rm -f /var/lib/dpkg/lock-frontend 2>/dev/null
	sudo rm -f /var/lib/dpkg/lock 2>/dev/null
	sudo rm -f /var/cache/apt/archives/lock 2>/dev/null
	sudo dpkg --configure -a
	sudo systemctl stop unattended-upgrades
	# sudo pkill --signal SIGKILL unattended-upgrades
	sudo apt-get purge unattended-upgrades
	return 0
}

# Detect operating system distribution
check_distro() {
	log "INFO" "Detecting operating system distribution..."

	# macOS
	if [ "$(uname)" = "Darwin" ]; then
		DISTRO_NAME="macos"
		DISTRO_VERSION=$(sw_vers -productVersion)
		log "INFO" "Detected distro: $DISTRO_NAME $DISTRO_VERSION"
	# Linux
	elif [ -f /etc/os-release ]; then
		. /etc/os-release
		DISTRO_NAME=$ID
		DISTRO_VERSION=$VERSION_ID
		log "INFO" "Detected distro: $DISTRO_NAME $DISTRO_VERSION"
	else
		log "WARN" "Unable to detect distro; using defaults"
		DISTRO_NAME="unknown"
		DISTRO_VERSION="unknown"
	fi

	# if this is not Ubuntu 22 or 24, return 1
	if [ "$DISTRO_NAME" != "ubuntu" ] || { [[ "$DISTRO_VERSION" != 22.* ]] && [[ "$DISTRO_VERSION" != 24.* ]]; }; then
		log "WARN" "Unsupported distro $DISTRO_NAME $DISTRO_VERSION"
		return 1
	fi
}

# Check user has sudo privileges
check_user() {
	log "INFO" "Checking user settings for execution environment"
	log "DEBUG" "Checking who is running the script"
	local CURRENT_USER
	CURRENT_USER=$(whoami)
	# if current user is in sudoers
	if sudo -l -U "$CURRENT_USER" 2>&1 | tee -a "$LOG_FILE"; then
		log "DEBUG" "Current user $CURRENT_USER has sudo privileges, continuing"
	else
		log "ERROR" "Current user $CURRENT_USER does not have sudo privileges, cannot continue"
		return 1
	fi
}

check_sudo_command() {
	if ! command -v sudo >/dev/null 2>&1; then
		log "ERROR" "'sudo' command is required but not found in PATH"
		return 1
	fi
	return 0
}

check_systemctl_command() {
	if ! command -v systemctl >/dev/null 2>&1; then
		log "ERROR" "'systemctl' command is required but not found in PATH"
		return 1
	fi
	return 0
}

ensure_curl_installed() {
	if command -v curl >/dev/null 2>&1; then
		log "INFO" "curl already installed"
		return 0
	fi
	log "INFO" "curl not found; installing via apt-get"
	if ! sudo apt-get update -y >>"$LOG_FILE" 2>&1; then
		log "ERROR" "Failed to update apt cache while installing curl"
		return 1
	fi
	if ! sudo apt-get install -y curl >>"$LOG_FILE" 2>&1; then
		log "ERROR" "Failed to install curl"
		return 1
	fi
	log "INFO" "curl installed successfully"
	return 0
}

ensure_lsb_release_installed() {
	if command -v lsb_release >/dev/null 2>&1; then
		log "INFO" "lsb_release already installed"
		return 0
	fi
	log "INFO" "lsb_release not found; installing via apt-get"
	if ! sudo apt-get update -y >>"$LOG_FILE" 2>&1; then
		log "ERROR" "Failed to update apt cache while installing lsb_release"
		return 1
	fi
	if ! sudo apt-get install -y lsb-release >>"$LOG_FILE" 2>&1; then
		log "ERROR" "Failed to install lsb_release"
		return 1
	fi
	log "INFO" "lsb_release installed successfully"
	return 0
}

ensure_ssh_keygen_available() {
	if command -v ssh-keygen >/dev/null 2>&1; then
		log "INFO" "ssh-keygen already installed"
		return 0
	fi
	log "INFO" "ssh-keygen not found; installing openssh-client via apt-get"
	if ! sudo apt-get update -y >>"$LOG_FILE" 2>&1; then
		log "ERROR" "Failed to update apt cache while installing openssh-client"
		return 1
	fi
	if ! sudo apt-get install -y openssh-client >>"$LOG_FILE" 2>&1; then
		log "ERROR" "Failed to install openssh-client"
		return 1
	fi
	log "INFO" "openssh-client installed successfully (ssh-keygen available)"
	return 0
}

ensure_rsync_installed() {
	if command -v rsync >/dev/null 2>&1; then
		log "INFO" "rsync already installed"
		return 0
	fi
	log "INFO" "rsync not found; installing via apt-get"
	if ! sudo apt-get update -y >>"$LOG_FILE" 2>&1; then
		log "ERROR" "Failed to update apt cache while installing rsync"
		return 1
	fi
	if ! sudo apt-get install -y rsync >>"$LOG_FILE" 2>&1; then
		log "ERROR" "Failed to install rsync"
		return 1
	fi
	log "INFO" "rsync installed successfully"
	return 0
}
