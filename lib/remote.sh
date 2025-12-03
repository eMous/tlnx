#!/bin/bash

# Remote execution helpers

# Transfer the project to the remote host and execute it
remote_execution() {
	check_binaries || {
		log "ERROR" "Failed to Acquire necessary binaries to execute remote commands."
		exit 1
	}
	local target_host=$1
	local target_user=$2
	local target_port=$3
	local target_password="$4"

	log "INFO" "Transferring project to remote host: $target_user@$target_host:$target_port"

	# Base SSH/rsync options (skip host key prompts for automation)
	local ssh_base=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p "$target_port")
	local rsync_base=(-av --progress -e "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p $target_port")

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
	local remote_project_dir="/opt/tlnx"
	local remote_temp_dir="/tmp"
	local current_dir=$(pwd)
	local local_tar_file="/tmp/tlnx-${timestamp}.tar.gz" # archive within project directory
	log "INFO" "Creating project directory on remote host: $remote_project_dir"

	# Create directory and capture output
	# read cmds by heredoc
	local cmds_to_run=$(
		cat <<EOF
mkdir -p $remote_project_dir
# if there is not empty in remote_project_dir, back it up
if [ -d "$remote_project_dir" ] && [ "\$(ls -A $remote_project_dir)" ]; then
	mkdir -p /opt/tlnx.bak	
	mv $remote_project_dir /opt/tlnx.bak/"tlnx.bak.${timestamp}"
	mkdir -p $remote_project_dir
fi
EOF
	)

	"${ssh_cmd[@]}" "$target_user@$target_host" "$cmds_to_run"  2>&1 | tee -a "$LOG_FILE"

	if [ ${PIPESTATUS[0]} -ne 0 ]; then
		log "ERROR" "Unable to create remote project directory"
		exit 1
	fi

	# 2. Compress local folder
	log "INFO" "Archiving project into $local_tar_file"
	cd "$PROJECT_DIR" 
	tar -czf "$local_tar_file" --exclude='*.tar.gz' --exclude='.log' --exclude='.vscode' . 2>&1 | tee -a "$LOG_FILE"
	cd "$current_dir"
	if [ ${PIPESTATUS[0]} -ne 0 ]; then
		log "ERROR" "Unable to archive local project"
		exit 1
	fi

	# 3. Transfer archive with rsync
	log "INFO" "Uploading archive via rsync"
	echo "[DEBUG] Full rsync command: ${rsync_cmd[*]} $local_tar_file $target_user@$target_host:$remote_temp_dir/" >>"$LOG_FILE"
	"${rsync_cmd[@]}" "$local_tar_file" "$target_user@$target_host:$remote_temp_dir/"

	if [ $? -ne 0 ]; then
		log "ERROR" "Failed to transfer archive to remote host"
		rm -f "$local_tar_file" # cleanup local temp file
		exit 1
	fi

	# 4. Extract on remote host
	log "INFO" "Extracting archive on remote host: $remote_project_dir"
	"${ssh_cmd[@]}" "$target_user@$target_host" "tar -xzf $remote_temp_dir/$(basename $local_tar_file) -C $remote_project_dir --strip-components=1" >>"$LOG_FILE" 2>&1

	if [ $? -ne 0 ]; then
		log "ERROR" "Failed to extract archive on remote host"
		rm -f "$local_tar_file" # cleanup local temp file
		exit 1
	fi

	# 5. Cleanup
	log "INFO" "Cleaning up temporary files"
	rm -f "$local_tar_file" # cleanup local temp file
	"${ssh_cmd[@]}" "$target_user@$target_host" "rm -f $remote_temp_dir/$(basename $local_tar_file)" >>"$LOG_FILE" 2>&1

	if [ $? -ne 0 ]; then
		log "WARN" "Unable to remove remote temporary archive"
		# Continue regardless
	fi

	# 6. Flip execution flag on remote config
	log "INFO" "Updating remote config to set REMOTE_RUN=false"
	"${ssh_cmd[@]}" "$target_user@$target_host" "sed -i 's/^REMOTE_RUN=.*/REMOTE_RUN=\"false\"/' $remote_project_dir/config/default.conf" >>"$LOG_FILE" 2>&1

	# 7. Connect and execute remotely while passing origin host info
	local client_hostname=$(hostname)
	log "INFO" "Connecting to remote host and starting shell"
	"${ssh_cmd[@]}" -t "$target_user@$target_host" "cd $remote_project_dir && SSH_CLIENT_HOST=${client_hostname} ./tlnx -h; bash"

	if [ $? -ne 0 ]; then
		log "ERROR" "Remote execution failed"
		exit 1
	fi

	log "INFO" "Remote execution finished"
	exit 0
}

check_binaries() {
	# Check for ssh
	if ! command -v ssh >/dev/null 2>&1; then
		log "ERROR" "ssh command not found. Please install OpenSSH client."
		exit 1
	fi

	# Check for rsync
	if ! command -v rsync >/dev/null 2>&1; then
		log "ERROR" "rsync command not found. Please install rsync."
		exit 1
	fi

	# Check for sshpass if password is to be used
	if [ -n "$TARGET_PASSWORD" ] && [ "$TARGET_PASSWORD" != "!!!!!!!ENCRYPTED!!!!!!!" ]; then
		if ! command -v sshpass >/dev/null 2>&1; then
			log "ERROR" "sshpass command not found. Please install sshpass to use password authentication."
			exit 1
		fi
	fi
	return 0
}
