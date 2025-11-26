#!/bin/bash

# init模块 - 系统初始化配置

# 更新阿里云镜像源
init_update_aliyun_mirror() {
    log "INFO" "开始更新阿里云镜像源"
    
    # 检测系统发行版
    log "INFO" "当前系统：$DISTRO $VERSION"
    
    if [ "$DISTRO" = "ubuntu" ]; then
        # Ubuntu系统
        log "INFO" "检测到Ubuntu系统，更新apt源为阿里云镜像"
        
        # 检查Ubuntu版本是否为22.04或24.04
        if [ "$VERSION" = "22.04" ] || [ "$VERSION" = "24.04" ]; then
            log "INFO" "当前Ubuntu版本 $VERSION 受支持，继续执行配置"
        else
            log "WARN" "当前Ubuntu版本 $VERSION 不在支持范围内，仍将继续执行配置，但可能会遇到问题"
        fi
        
        # 备份原始源文件
        sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak
        
        # 更新为阿里云镜像源
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
        
        # 更新apt缓存
        sudo apt-get update -y
        
    elif [ "$DISTRO_ID" = "centos" ] || [ "$DISTRO_ID" = "rocky" ] || [ "$DISTRO_ID" = "almalinux" ]; then
        # CentOS/Rocky/AlmaLinux系统
        log "INFO" "检测到CentOS/Rocky/AlmaLinux系统，更新yum源为阿里云镜像"
        
        # 备份原始源文件
        sudo cp /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.bak 2>/dev/null || true
        sudo cp /etc/yum.repos.d/Rocky-BaseOS.repo /etc/yum.repos.d/Rocky-BaseOS.repo.bak 2>/dev/null || true
        sudo cp /etc/yum.repos.d/AlmaLinux-BaseOS.repo /etc/yum.repos.d/AlmaLinux-BaseOS.repo.bak 2>/dev/null || true
        
        # 更新为阿里云镜像源
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
        
        # 清理并更新yum缓存
        sudo yum clean all
        sudo yum makecache
    else
        log "WARN" "不支持的发行版 $DISTRO_ID，跳过镜像源更新"
    fi
    
    log "INFO" "阿里云镜像源更新完成"
}

# 模块入口函数 - init
init_main() {
    log "INFO" "=== 开始执行init模块 ==="
    
    init_update_aliyun_mirror
    
    log "INFO" "=== init模块执行完成 ==="
}