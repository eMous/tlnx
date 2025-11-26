#!/bin/bash

# 配置相关函数

# 函数：检测操作系统发行版
detect_distro() {
    log "INFO" "检测操作系统发行版..."
    
    # 检测是否为macOS
    if [ "$(uname)" = "Darwin" ]; then
        DISTRO_NAME="macos"
        DISTRO_VERSION=$(sw_vers -productVersion)
        log "INFO" "检测到发行版: $DISTRO_NAME $DISTRO_VERSION"
    # 检测是否为Linux
    elif [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_NAME=$ID
        DISTRO_VERSION=$VERSION_ID
        log "INFO" "检测到发行版: $DISTRO_NAME $DISTRO_VERSION"
    else
        log "WARNING" "无法检测发行版，使用默认配置"
        DISTRO_NAME="unknown"
        DISTRO_VERSION="unknown"
    fi
}

# 函数：解密配置字符串
decrypt_config() {
    log "INFO" "检查是否存在加密配置文件..."
    
    # 检查加密配置文件是否存在
    if [ -f "config/enc.conf.enc" ]; then
        # 检查解密后的配置文件是否存在且比加密文件更新
        if [ -f "config/enc.conf" ] && [ "config/enc.conf" -nt "config/enc.conf.enc" ]; then
            log "INFO" "解密后的配置文件已存在且比加密文件更新，直接加载..."
            # 加载解密后的配置
            source "config/enc.conf"
            log "INFO" "加密配置加载成功"
            return 0
        else
            # 详细记录解密原因
            if [ ! -f "config/enc.conf" ]; then
                log "INFO" "未发现解密后的配置文件，开始解密..."
            else
                log "INFO" "发现解密后的配置文件但比加密文件旧，开始解密..."
            fi
            
            # 检查解密脚本是否存在
            if [ -f "scripts/decrypt.sh" ]; then
                # 获取默认密钥环境变量名
                DEFAULT_KEY_ENV=${CONFIG_DEFAULT_KEY_ENV:-"CONFIG_KEY"}
                
                # 执行解密脚本，将解密内容写入config/enc.conf
                if . "scripts/decrypt.sh" "config/enc.conf.enc" "config/enc.conf" "$DEFAULT_KEY_ENV"; then
                    log "INFO" "加密配置文件解密成功"
                    
                    # 检查解密后的配置文件是否存在
                    if [ -f "config/enc.conf" ]; then
                        # 加载解密后的配置
                        log "INFO" "开始加载解密后的配置..."
                        source "config/enc.conf"
                        log "INFO" "加密配置加载成功"
                        return 0
                    else
                        log "ERROR" "解密后的配置文件不存在"
                        return 1
                    fi
                else
                    log "ERROR" "加密配置文件解密失败"
                    return 1
                fi
            else
                log "WARNING" "解密脚本不存在: scripts/decrypt.sh，跳过解密"
                return 1
            fi
        fi
    else
        log "INFO" "未发现加密配置文件，跳过解密"
        return 1
    fi
}

# 函数：加载默认配置
load_config() {
    log "INFO" "加载默认配置..."
    
    # 1. 加载默认配置文件
    if [ -f "config/default.conf" ]; then
        . "config/default.conf"
        log "INFO" "默认配置加载成功"
    else
        log "ERROR" "默认配置文件不存在: config/default.conf"
        exit 1
    fi
    
    # 2. 解密并加载加密配置
    decrypt_config
    
    # 3. 检查模块序列变量名，确保兼容旧配置
    if [ -z "${CONFIG_MODULES+set}" ] && [ -n "${MODULES+set}" ]; then
        CONFIG_MODULES=("${MODULES[@]}")
    fi
    
    # 4. 将 TARGET_ENC_* 变量的值赋给对应的 TARGET_* 变量
    TARGET_HOST="$TARGET_ENC_HOST"
    TARGET_USER="$TARGET_ENC_USER"
    TARGET_PORT="$TARGET_ENC_PORT"
    TARGET_PASSWORD="$TARGET_ENC_PASSWORD"
}