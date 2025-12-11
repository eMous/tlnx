#!/bin/bash 

_detect_prerequisites() {
	check_user || {
		log "ERROR" "User check failed. Exiting."
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
}

check_aptlock(){
	sudo killall apt apt-get dpkg 
	sudo rm -f /var/lib/dpkg/lock-frontend
	sudo rm -f /var/lib/dpkg/lock
	sudo rm -f /var/cache/apt/archives/lock
	sudo dpkg --configure -a
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
