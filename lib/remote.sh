#!/bin/bash

# 远程执行相关函数

# 函数：传输项目到远程主机并直接执行
remote_execution() {
    local target_host=$1
    local target_user=$2
    local target_port=${3:-22}
    local target_password="${4:-$TARGET_PASSWORD}"
    
    log "INFO" "开始传输项目到远程主机: $target_user@$target_host:$target_port"
    
    # 定义SSH和rsync命令数组
    local ssh_base=(-p $target_port)
    local rsync_base=(-av --progress -e "ssh -p $target_port")
    
    # 完整的命令数组
    local ssh_cmd=(ssh "${ssh_base[@]}")
    local rsync_cmd=(rsync "${rsync_base[@]}")
    
    # 如果提供了密码，使用sshpass进行认证
    if [ -n "$target_password" ] && [ "$target_password" != "!!!!!!!ENCRYPTED!!!!!!!" ]; then
        ssh_cmd=(sshpass -p "$target_password" "${ssh_cmd[@]}")
        rsync_cmd=(sshpass -p "$target_password" "${rsync_cmd[@]}")
    fi
    
    # 1. 定义项目目录为/root/tlnx-${timestamp}
    local timestamp=$(date +%Y%m%d%H%M%S)
    local remote_project_dir="/root/tlnx-${timestamp}"
    local remote_temp_dir="/tmp"
    local local_tar_file="$(pwd)/tlnx-${timestamp}.tar.gz"  # 在当前项目目录下创建压缩文件
    log "INFO" "在远程主机创建项目目录: $remote_project_dir"
    
    # 执行命令并输出详细信息
    "${ssh_cmd[@]}" "$target_user@$target_host" "mkdir -p $remote_project_dir" >> "$LOG_FILE" 2>&1
    
    if [ $? -ne 0 ]; then
        log "ERROR" "无法在远程主机创建项目目录"
        exit 1
    fi
    
    # 2. 压缩本地文件夹为tar.gz
    log "INFO" "压缩本地文件夹为tar.gz: $local_tar_file"
    tar -czf "$local_tar_file" --exclude='*.tar.gz' --exclude='.git' --exclude='.log' --exclude='.vscode' "./" >> "$LOG_FILE" 2>&1
    
    if [ $? -ne 0 ]; then
        log "ERROR" "无法压缩本地文件夹"
        exit 1
    fi
    
    # 3. 使用rsync将压缩包传输到远程临时目录
    log "INFO" "使用rsync将压缩包传输到远程临时目录"
    echo "[DEBUG] 完整rsync命令: ${rsync_cmd[*]} $local_tar_file $target_user@$target_host:$remote_temp_dir/" >> "$LOG_FILE"
    "${rsync_cmd[@]}" "$local_tar_file" "$target_user@$target_host:$remote_temp_dir/"
    
    if [ $? -ne 0 ]; then
        log "ERROR" "无法传输压缩包到远程主机"
        rm -f "$local_tar_file"  # 清理本地临时文件
        exit 1
    fi
    
    # 4. 在远程主机上解压压缩包到最终目录
    log "INFO" "在远程主机上解压压缩包到最终目录: $remote_project_dir"
    "${ssh_cmd[@]}" "$target_user@$target_host" "tar -xzf $remote_temp_dir/$(basename $local_tar_file) -C $remote_project_dir --strip-components=1" >> "$LOG_FILE" 2>&1
    
    if [ $? -ne 0 ]; then
        log "ERROR" "无法在远程主机解压压缩包"
        rm -f "$local_tar_file"  # 清理本地临时文件
        exit 1
    fi
    
    # 5. 清理临时文件
    log "INFO" "清理临时文件"
    rm -f "$local_tar_file"  # 清理本地临时文件
    "${ssh_cmd[@]}" "$target_user@$target_host" "rm -f $remote_temp_dir/$(basename $local_tar_file)" >> "$LOG_FILE" 2>&1
    
    if [ $? -ne 0 ]; then
        log "WARNING" "无法清理远程临时文件"
        # 不退出，继续执行后续步骤
    fi
    
    # 3. 修改远程配置文件，将IS_EXECUTION_ENVIRONMENT设为true
    log "INFO" "修改远程配置文件，将IS_EXECUTION_ENVIRONMENT设为true"
    "${ssh_cmd[@]}" "$target_user@$target_host" "sed -i 's/^IS_EXECUTION_ENVIRONMENT=.*/IS_EXECUTION_ENVIRONMENT=\"true\"/' $remote_project_dir/config/default.conf" >> "$LOG_FILE" 2>&1
    
    # 4. 获取本地主机名，直接执行ssh -t命令，cd到远程项目目录并执行bash，传递SSH_CLIENT_HOST环境变量
    local client_hostname=$(hostname)
    log "INFO" "连接到远程主机并执行bash"
    "${ssh_cmd[@]}" -t "$target_user@$target_host" "cd $remote_project_dir && SSH_CLIENT_HOST=${client_hostname} ./main.sh -h; bash"
    
    if [ $? -ne 0 ]; then
        log "ERROR" "远程连接执行失败"
        exit 1
    fi
    
    log "INFO" "远程执行完成"
    exit 0
}