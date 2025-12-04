#!/bin/bash

# Docker module - install and configure Docker

# Check whether Docker is already installed
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


# Module entrypoint
_docker_install() {
	log "INFO" "=== Starting Docker installation and configuration ==="

	docker_install
	if [ $? -ne 0 ]; then
		return 1
	fi

	log "INFO" "=== Docker installation and configuration completed ==="
	return 0
}
