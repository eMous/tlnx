#!/bin/bash

# 通用函数库

# 确保日志目录存在
mkdir -p logs

# 设置日志文件路径
LOG_FILE="logs/server_config.log"

# 函数：记录日志
log() {
    local level=$1
    local message=$2
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    echo "[$timestamp] [$level] $message"
}