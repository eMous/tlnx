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
        
        if [[ "$DISTRO_VERSION" == 22.* ]] || [[ "$DISTRO_VERSION" == 24.* ]]; then
            log "INFO" "Ubuntu $DISTRO_VERSION is supported"
        else
            log "WARN" "Ubuntu $DISTRO_VERSION is outside the tested range; continuing anyway"
        fi
        
        sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
        sudo cat > /etc/apt/sources.list << EOF
deb http://mirrors.aliyun.com/ubuntu/ $(lsb_release -cs) main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ $(lsb_release -cs) main restricted universe multiverse

deb http://mirrors.aliyun.com/ubuntu/ $(lsb_release -cs)-security main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ $(lsb_release -cs)-security main restricted universe multiverse

deb http://mirrors.aliyun.com/ubuntu/ $(lsb_release -cs)-updates main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ $(lsb_release -cs)-updates main restricted universe multiverse

deb http://mirrors.aliyun.com/ubuntu/ $(lsb_release -cs)-proposed main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ $(lsb_release -cs)-proposed main restricted universe multiverse

deb http://mirrors.aliyun.com/ubuntu/ $(lsb_release -cs)-backports main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ $(lsb_release -cs)-backports main restricted universe multiverse
EOF
        
        sudo apt-get update -y
        
    elif [ "$DISTRO_NAME" = "centos" ] || [ "$DISTRO_NAME" = "rocky" ] || [ "$DISTRO_NAME" = "almalinux" ]; then
        log "INFO" "Detected CentOS/Rocky/AlmaLinux, switching yum repos to Alibaba Cloud"
        
        sudo cp /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.bak 2>/dev/null || true
        sudo cp /etc/yum.repos.d/Rocky-BaseOS.repo /etc/yum.repos.d/Rocky-BaseOS.repo.bak 2>/dev/null || true
        sudo cp /etc/yum.repos.d/AlmaLinux-BaseOS.repo /etc/yum.repos.d/AlmaLinux-BaseOS.repo.bak 2>/dev/null || true
        
        if [ -f "/etc/os-release" ]; then
            . /etc/os-release
            
            if [ "$ID" = "centos" ]; then
                sudo curl -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-$VERSION_ID.repo
            elif [ "$ID" = "rocky" ]; then
                sudo curl -o /etc/yum.repos.d/Rocky-BaseOS.repo http://mirrors.aliyun.com/repo/Rocky-$VERSION_ID.repo
            elif [ "$ID" = "almalinux" ]; then
                sudo curl -o /etc/yum.repos.d/AlmaLinux-BaseOS.repo http://mirrors.aliyun.com/repo/AlmaLinux-$VERSION_ID.repo
            fi
        fi
        
        sudo yum clean all
        sudo yum makecache
    else
        log "WARN" "Unsupported distribution $DISTRO_NAME, skipping mirror update"
    fi
    
    log "INFO" "Finished updating Alibaba Cloud mirrors"
}

# Module entrypoint - init
_init_install() {
    log "INFO" "=== Starting init module ==="
    
    init_update_aliyun_mirror
    
    log "INFO" "=== init module completed ==="
}
