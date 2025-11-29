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
            sudo tee /etc/apt/sources.list >/dev/null << EOF
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
    init_user_check
    init_enable_bbr
    init_update_aliyun_mirror
    
    log "INFO" "=== init module completed ==="
}

# Check user settings: aim to run as 'tom' which included in sudoers list in execution environment, move dir to tom's home
init_user_check() {
    log "INFO" "Checking user settings for execution environment"
    log "DEBUG" "Checking who is running the script"
    local CURRENT_USER
    CURRENT_USER=$(whoami)
    # if current user is in sudoers
    if sudo -l -U "$CURRENT_USER" &>/dev/null; then
        log "DEBUG" "Current user $CURRENT_USER has sudo privileges, continuing"
    else
        log "ERROR" "Current user $CURRENT_USER does not have sudo privileges, cannot continue"
        exit 1
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
