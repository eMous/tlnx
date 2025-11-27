#!/bin/bash

# Configuration helpers

# Detect operating system distribution
detect_distro() {
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
        log "WARNING" "Unable to detect distro; using defaults"
        DISTRO_NAME="unknown"
        DISTRO_VERSION="unknown"
    fi
}

# Decrypt configuration when encrypted file exists
decrypt_config() {
    log "INFO" "Checking for encrypted configuration..."
    
    if [ -f "config/enc.conf.enc" ]; then
        if [ -f "config/enc.conf" ] && [ "config/enc.conf" -nt "config/enc.conf.enc" ]; then
            log "INFO" "Decrypted config is newer than encrypted source; loading"
            source "config/enc.conf"
            log "INFO" "Encrypted configuration loaded"
            return 0
        else
            if [ ! -f "config/enc.conf" ]; then
                log "INFO" "Decrypted config missing; running decryption"
            else
                log "INFO" "Decrypted config older than encrypted file; running decryption"
            fi
            
            if [ -f "scripts/decrypt.sh" ]; then
                DEFAULT_KEY_ENV=${CONFIG_DEFAULT_KEY_ENV:-"CONFIG_KEY"}
                
                if . "scripts/decrypt.sh" "config/enc.conf.enc" "config/enc.conf" "$DEFAULT_KEY_ENV"; then
                    log "INFO" "Encrypted config decrypted"
                    
                    if [ -f "config/enc.conf" ]; then
                        log "INFO" "Loading decrypted configuration"
                        source "config/enc.conf"
                        log "INFO" "Encrypted configuration loaded"
                        return 0
                    else
                        log "ERROR" "Decrypted configuration missing"
                        return 1
                    fi
                else
                    log "ERROR" "Failed to decrypt encrypted configuration"
                    return 1
                fi
            else
                log "WARNING" "scripts/decrypt.sh not found; skipping decryption"
                return 1
            fi
        fi
    else
        log "INFO" "Encrypted configuration not found; skipping"
        return 1
    fi
}

# Load default configuration
load_config() {
    log "INFO" "Loading default configuration..."
    
    if [ -f "config/default.conf" ]; then
        . "config/default.conf"
        log "INFO" "Default configuration loaded"
    else
        log "ERROR" "Default configuration missing: config/default.conf"
        exit 1
    fi
    
    decrypt_config
    
    if [ -z "${CONFIG_MODULES+set}" ] && [ -n "${MODULES+set}" ]; then
        CONFIG_MODULES=("${MODULES[@]}")
    fi
    
    TARGET_HOST="$TARGET_ENC_HOST"
    TARGET_USER="$TARGET_ENC_USER"
    TARGET_PORT="$TARGET_ENC_PORT"
    TARGET_PASSWORD="$TARGET_ENC_PASSWORD"
}
