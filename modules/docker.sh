#!/bin/bash

# Docker 模块 - 安装和配置 Docker

# 检查Docker模块是否已安装
_docker_check_installed() {
    # 检查docker命令是否存在
    if command -v docker > /dev/null 2>&1; then
        log "DEBUG" "Docker 已经安装"
        return 0
    else
        log "DEBUG" "Docker 未安装"
        return 1
    fi
}

# 日志记录
log "INFO" "=== 开始安装和配置 Docker ===="

# 安装 Docker
_docker_install() {
    log "INFO" "安装 Docker..."
    
    # 更新包列表
    sudo apt-get update >> "$LOG_FILE" 2>&1
    
    # 安装必要的依赖
    sudo apt-get install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common >> "$LOG_FILE" 2>&1
    
    # 添加 Docker GPG 密钥
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - >> "$LOG_FILE" 2>&1
    
    # 添加 Docker 仓库
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" >> "$LOG_FILE" 2>&1
    
    # 再次更新包列表
    sudo apt-get update >> "$LOG_FILE" 2>&1
    
    # 安装 Docker
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        log "INFO" "Docker 安装成功"
    else
        log "ERROR" "Docker 安装失败"
        return 1
    fi
}

# 启动 Docker 服务
docker_start() {
    log "INFO" "启动 Docker 服务..."
    
    sudo systemctl start docker >> "$LOG_FILE" 2>&1
    sudo systemctl enable docker >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        log "INFO" "Docker 服务启动成功"
    else
        log "ERROR" "Docker 服务启动失败"
        return 1
    fi
}

# 安装 Docker Compose
docker_compose_install() {
    log "INFO" "安装 Docker Compose..."
    
    # 使用默认版本或配置文件中的版本
    local compose_version=${DOCKER_COMPOSE_VERSION:-"v2.20.0"}
    
    # 下载 Docker Compose
    sudo curl -L "https://github.com/docker/compose/releases/download/$compose_version/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose >> "$LOG_FILE" 2>&1
    
    # 添加执行权限
    sudo chmod +x /usr/local/bin/docker-compose >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        log "INFO" "Docker Compose 安装成功"
    else
        log "ERROR" "Docker Compose 安装失败"
        return 1
    fi
}

# 主函数
docker_main() {
    # 确保Docker服务启动
    docker_start
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    # 确保Docker Compose已安装
    # 检查docker-compose命令是否存在
    if ! command -v docker-compose > /dev/null 2>&1; then
        docker_compose_install
        if [ $? -ne 0 ]; then
            return 1
        fi
    fi
    
    log "INFO" "=== Docker 安装和配置完成 ==="
    return 0
}


