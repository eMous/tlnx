#!/bin/bash

# Remote execution helpers

# Transfer the project to the remote host and execute it
remote_execution() {
    local target_host=$1
    local target_user=$2
    local target_port=${3:-22}
    local target_password="${4:-$TARGET_PASSWORD}"
    
    log "INFO" "Transferring project to remote host: $target_user@$target_host:$target_port"
    
    # Base SSH/rsync options
    local ssh_base=(-p $target_port)
    local rsync_base=(-av --progress -e "ssh -p $target_port")
    
    # Full command arrays
    local ssh_cmd=(ssh "${ssh_base[@]}")
    local rsync_cmd=(rsync "${rsync_base[@]}")
    
    # Use sshpass if a password is available
    if [ -n "$target_password" ] && [ "$target_password" != "!!!!!!!ENCRYPTED!!!!!!!" ]; then
        ssh_cmd=(sshpass -p "$target_password" "${ssh_cmd[@]}")
        rsync_cmd=(sshpass -p "$target_password" "${rsync_cmd[@]}")
    fi
    
    # 1. Remote project directory
    local timestamp=$(date +%Y%m%d%H%M%S)
    local remote_project_dir="/root/tlnx-${timestamp}"
    local remote_temp_dir="/tmp"
    local local_tar_file="$(pwd)/tlnx-${timestamp}.tar.gz"  # archive within project directory
    log "INFO" "Creating project directory on remote host: $remote_project_dir"
    
    # Create directory and capture output
    "${ssh_cmd[@]}" "$target_user@$target_host" "mkdir -p $remote_project_dir" >> "$LOG_FILE" 2>&1
    
    if [ $? -ne 0 ]; then
        log "ERROR" "Unable to create remote project directory"
        exit 1
    fi
    
    # 2. Compress local folder
    log "INFO" "Archiving project into $local_tar_file"
    tar -czf "$local_tar_file" --exclude='*.tar.gz' --exclude='.log' --exclude='.vscode' "./" >> "$LOG_FILE" 2>&1
    
    if [ $? -ne 0 ]; then
        log "ERROR" "Unable to archive local project"
        exit 1
    fi
    
    # 3. Transfer archive with rsync
    log "INFO" "Uploading archive via rsync"
    echo "[DEBUG] Full rsync command: ${rsync_cmd[*]} $local_tar_file $target_user@$target_host:$remote_temp_dir/" >> "$LOG_FILE"
    "${rsync_cmd[@]}" "$local_tar_file" "$target_user@$target_host:$remote_temp_dir/"
    
    if [ $? -ne 0 ]; then
        log "ERROR" "Failed to transfer archive to remote host"
        rm -f "$local_tar_file"  # cleanup local temp file
        exit 1
    fi
    
    # 4. Extract on remote host
    log "INFO" "Extracting archive on remote host: $remote_project_dir"
    "${ssh_cmd[@]}" "$target_user@$target_host" "tar -xzf $remote_temp_dir/$(basename $local_tar_file) -C $remote_project_dir --strip-components=1" >> "$LOG_FILE" 2>&1
    
    if [ $? -ne 0 ]; then
        log "ERROR" "Failed to extract archive on remote host"
        rm -f "$local_tar_file"  # cleanup local temp file
        exit 1
    fi
    
    # 5. Cleanup
    log "INFO" "Cleaning up temporary files"
    rm -f "$local_tar_file"  # cleanup local temp file
    "${ssh_cmd[@]}" "$target_user@$target_host" "rm -f $remote_temp_dir/$(basename $local_tar_file)" >> "$LOG_FILE" 2>&1
    
    if [ $? -ne 0 ]; then
        log "WARNING" "Unable to remove remote temporary archive"
        # Continue regardless
    fi
    
    # 6. Flip execution flag on remote config
    log "INFO" "Updating remote config to set IS_EXECUTION_ENVIRONMENT=true"
    "${ssh_cmd[@]}" "$target_user@$target_host" "sed -i 's/^IS_EXECUTION_ENVIRONMENT=.*/IS_EXECUTION_ENVIRONMENT=\"true\"/' $remote_project_dir/config/default.conf" >> "$LOG_FILE" 2>&1
    
    # 7. Connect and execute remotely while passing origin host info
    local client_hostname=$(hostname)
    log "INFO" "Connecting to remote host and starting shell"
    "${ssh_cmd[@]}" -t "$target_user@$target_host" "cd $remote_project_dir && SSH_CLIENT_HOST=${client_hostname} ./main.sh -h; bash"
    
    if [ $? -ne 0 ]; then
        log "ERROR" "Remote execution failed"
        exit 1
    fi
    
    log "INFO" "Remote execution finished"
    exit 0
}
