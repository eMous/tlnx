#!/bin/bash

# Docker module - install and configure Docker

# Check whether Docker is already installed
_docker_check_installed() {
	if command -v docker >/dev/null 2>&1; then
		log "DEBUG" "Docker already installed"
		return 0
	else
		log "DEBUG" "Docker not installed"
		return 1
	fi
}

# Install Docker packages
docker_install() {
	log "INFO" "Installing Docker..."

	# Refresh package list
	sudo apt-get update >>"$LOG_FILE" 2>&1

	# Install required dependencies
	sudo apt-get install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common >>"$LOG_FILE" 2>&1

	# Import Docker GPG key
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - >>"$LOG_FILE" 2>&1

	# Add Docker repository
	sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" >>"$LOG_FILE" 2>&1

	# Update package list again
	sudo apt-get update >>"$LOG_FILE" 2>&1

	# Install Docker packages
	sudo apt-get install -y docker-ce docker-ce-cli containerd.io >>"$LOG_FILE" 2>&1

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

	docker_start
	if [ $? -ne 0 ]; then
		return 1
	fi

	if ! command -v docker-compose >/dev/null 2>&1; then
		docker_compose_install
		if [ $? -ne 0 ]; then
			return 1
		fi
	fi

	log "INFO" "=== Docker installation and configuration completed ==="
	return 0
}
