#!/bin/bash

# 通用函数库

# 确保日志目录存在
mkdir -p logs

# 设置日志文件路径
LOG_FILE="logs/server_config.log"

# 默认日志级别
LOG_LEVEL=${LOG_LEVEL:-"INFO"}

# 定义日志级别优先级映射
LOG_LEVEL_PRIORITY=("DEBUG" "INFO" "WARN" "ERROR")

# 函数：获取日志级别的优先级数字
get_log_priority() {
    local level=$1
    for i in "${!LOG_LEVEL_PRIORITY[@]}"; do
        if [ "${LOG_LEVEL_PRIORITY[$i]}" = "$level" ]; then
            echo $i
            return
        fi
    done
    echo 1  # 默认返回INFO级别的优先级
}

# 函数：记录日志
log() {
    local level=$1
    local message=$2
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    # 始终写入日志文件
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    # 获取当前日志级别和消息日志级别的优先级
    local current_priority=$(get_log_priority "$LOG_LEVEL")
    local message_priority=$(get_log_priority "$level")
    
    # 只有当消息日志级别的优先级大于等于当前设置的日志级别时，才输出到控制台
    if [ $message_priority -ge $current_priority ]; then
        echo "[$timestamp] [$level] $message"
    fi
}