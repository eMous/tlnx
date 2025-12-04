#!/bin/bash

# Docker module - install and configure Docker

# Check whether Docker is already installed
# _docker_check_installed() {
# 	if command -v docker >/dev/null 2>&1; then
# 		log "DEBUG" "Docker already installed"
# 		return 0
# 	else
# 		log "DEBUG" "Docker not installed"
# 		return 1
# 	fi
# }

# Install Docker packages
docker_install() {
	log "INFO" "Installing Docker..."

	# Refresh package list
	sudo apt-get update 2>&1 | tee -a "$LOG_FILE"
	sudo apt-get remove $(dpkg --get-selections docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc | cut -f1) 2>&1 | tee -a "$LOG_FILE"
	sudo apt-get install ca-certificates curl 2>&1 | tee -a "$LOG_FILE"
	if [ ${PIPESTATUS[0]} -ne 0 ]; then
		log "ERROR" "Failed to install prerequisites for Docker"
		return 1
	fi
	sudo install -m 0755 -d /etc/apt/keyrings 2>&1 | tee -a "$LOG_FILE"
	if [ ${PIPESTATUS[0]} -ne 0 ]; then
		log "ERROR" "Failed to create /etc/apt/keyrings directory"
		return 1
	fi

	sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc 2>&1 | tee -a "$LOG_FILE"
	if [ ${PIPESTATUS[0]} -ne 0 ]; then
		log "ERROR" "Failed to download Docker GPG key"
		return 1
	fi

	sudo chmod a+r /etc/apt/keyrings/docker.asc 2>&1 | tee -a "$LOG_FILE"
	if [ ${PIPESTATUS[0]} -ne 0 ]; then
		log "ERROR" "Failed to set permissions on Docker GPG key"
		return 1
	fi

	command sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF

	sudo apt-get update 2>&1 | tee -a "$LOG_FILE"

	sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y 2>&1 | tee -a "$LOG_FILE"
	
	
	if [ $? -eq 0 ]; then
		log "INFO" "Docker installation succeeded"
	else
		log "ERROR" "Docker installation failed"
		return 1
	fi
}

# Start Docker service
docker_start() {
	log "INFO" "Starting Docker service..."

	sudo systemctl start docker >>"$LOG_FILE" 2>&1
	sudo systemctl enable docker >>"$LOG_FILE" 2>&1

	if [ $? -eq 0 ]; then
		log "INFO" "Docker service started"
	else
		log "ERROR" "Failed to start Docker service"
		return 1
	fi
}

# Install Docker Compose
docker_compose_install() {
	log "INFO" "Installing Docker Compose..."

	# Use configured version or fallback
	local compose_version=${DOCKER_COMPOSE_VERSION:-"v2.20.0"}

	# Download Docker Compose
	sudo curl -L "https://github.com/docker/compose/releases/download/$compose_version/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose >>"$LOG_FILE" 2>&1

	# Make binary executable
	sudo chmod +x /usr/local/bin/docker-compose >>"$LOG_FILE" 2>&1

	if [ $? -eq 0 ]; then
		log "INFO" "Docker Compose installation succeeded"
	else
		log "ERROR" "Docker Compose installation failed"
		return 1
	fi
}

# Module entrypoint
_docker_install() {
	log "INFO" "=== Starting Docker installation and configuration ==="

	docker_install
	if [ $? -ne 0 ]; then
		return 1
	fi

	# docker_start
	# if [ $? -ne 0 ]; then
	# 	return 1
	# fi

	# if ! command -v docker-compose >/dev/null 2>&1; then
	# 	docker_compose_install
	# 	if [ $? -ne 0 ]; then
	# 		return 1
	# 	fi
	# fi

	log "INFO" "=== Docker installation and configuration completed ==="
	return 0
}
