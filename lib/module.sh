#!/bin/bash

# Module execution helpers

# Usage helper (unused but kept for reference)
display_usage() {
	echo "Usage: $0 [options]"
	echo ""
	echo "Options:"
	echo "  -l, --log-level <level>   Set log level (DEBUG, INFO, WARN, ERROR); default INFO"
	echo "  -t, --test               Test mode: load config without running modules"
	echo "  --modules <list>        Comma-separated modules, e.g., --modules docker,zsh"
	echo "  -h, --help               Show help"
	echo "post-install callbacks for module $module"
	echo "Examples:"
	echo "  $0 -l DEBUG"
	echo "  $0 -t  # test configuration loading"
	echo "  $0 --modules docker,zsh  # run only docker and zsh"
}

# Execute a module
execute_module() {
	local module=$1
	local force=${2:-"false"}
	log "INFO" "Executing module: $module"

	if [ -f "$PROJECT_DIR/modules/$module.sh" ]; then
		source "$PROJECT_DIR/modules/$module.sh"
		local mark="${module}_installed_mark"
		local marks_file="$PROJECT_DIR/run/marks"
		local need_install=true

		if [ "$force" != "true" ]; then
			if module_check_installed "$module" "$mark" "$marks_file"; then
				log "INFO" "Module $module already installed by global examining; trying specific check"
				# if specific module's _check_install exists conduct it
				local check_func="_${module}_check_installed"
				if command -v "$check_func" &>/dev/null; then
					if "$check_func" "${module}" "${mark}" "${marks_file}"; then
						log "INFO" "Module $module passed specific check; skipping installation"
						need_install=false
					else
						need_install=true
						log "INFO" "Module $module failed specific check; starting installation"
					fi
				else
					log "INFO" "No specific check for module $module, no _${module}_check_installed; skipping installation"
					need_install=false
				fi
			else
				log "INFO" "Module $module not installed; starting installation"
			fi
		else
			log "INFO" "Force re-installation for module $module"
		fi

		if [ "$need_install" = "true" ]; then
			local install_func="_${module}_install"
			if command -v "$install_func" &>/dev/null; then
				"$install_func" "${module}" "${mark}" "${marks_file}"
				if [ $? -ne 0 ]; then
				 # if module in REQUIRED_MODULES, fail the entire process
					if [[ " ${CONFIG_REQUIRED_MODULES[*]} " == *" $module "* ]]; then
						log "ERROR" "Module $module is required and failed to install; aborting"
						exit 1
					fi
					log "ERROR" "Module $module failed to run $install_func"
					return 1
				fi
				module_install_callback "${module}"
				module_install_complete "${module}" "${mark}" "${marks_file}"
			else
				log "WARN" "Module $module is missing ${install_func}; skipping installation"
			fi
		fi

		log "INFO" "Module $module completed"
	else
		log "WARN" "Module script missing: modules/$module.sh; skipping"
		return 1
	fi
}

module_check_installed() {
	local module=$1
	local mark=$2
	local marks_file=$3
	if [ ! -f "$marks_file" ]; then
		log "WARN" "Marks file $marks_file does not exist; module $module considered not installed"
		mkdir -p "$(dirname "$marks_file")"
		touch "$marks_file"
		return 1
	fi
	if grep -Fq "$mark" "$marks_file"; then
		log "DEBUG" "${module} module mark $mark found in $marks_file"
	else
		log "WARN" "${module} module mark $mark not found in $marks_file; considered older"
		return 1
	fi

	local installed=""
	
	# Check watched environment variables
	local watched_func="_${module}_watched_vars"
	if command -v "$watched_func" &>/dev/null; then
		local watched_vars
		watched_vars=$("$watched_func")
		local var_changed=false
		
		for var in $watched_vars; do
			local current_val="${!var}"
			local cached_val
			cached_val=$(get_cached_env_value "$var")
			
			if [ "$current_val" != "$cached_val" ]; then
				log "INFO" "Watched variable $var changed for module $module; triggering reinstall"
				log "DEBUG" "Old: '$cached_val', New: '$current_val'"
				var_changed=true
				break
			fi
		done
		
		if [ "$var_changed" = "true" ]; then
			installed=false
		else
			# If vars didn't change, check script modification
			if ! mark_older_than "$mark" "$(stat -c %Y "$PROJECT_DIR/modules/${module}.sh")"; then
				log "DEBUG" "${module} module script not modified since last run"
				installed=true
			else
				log "INFO" "${module} module script modified since last run; module will run"
				installed=false
			fi
		fi
	else
		# Fallback to old logic if no watched vars defined
		if ! mark_older_than "$mark" "$(stat -c %Y "$PROJECT_DIR/config/default.conf")" &&
			! mark_older_than "$mark" "$(stat -c %Y "$PROJECT_DIR/config/enc.conf")"; then
			log "DEBUG" "${module} module already applied (mark found)"
			if ! mark_older_than "$mark" "$(stat -c %Y "$PROJECT_DIR/modules/${module}.sh")"; then
				log "DEBUG" "${module} module script not modified since last run"
				installed=true
			else
				log "INFO" "${module} module script modified since last run; module will run"
				installed=false
			fi
		else
			log "INFO" "${module} module config files modified since last run; module will run"
			installed=false
		fi
	fi


	if [ "$installed" = "true" ]; then
		return 0
	else
		# remove the mark
		sed -i "/^${mark}.*$/d" "$marks_file"
		return 1
	fi
}
module_install_complete() {
	local off_mark_control=("${OFF_MARK_CONTROL[@]}")
	local module=$1
	local mark=$2
	local mark_file=$3
	# if module is not in off_mark_control list add the mark
	if [[ " ${off_mark_control[*]} " == *" $module "* ]]; then
		log "INFO" "${module} module is in off_mark_control list; skipping mark addition"
		return 0
	fi
	# Add the mark
	add_mark "$mark" "$mark_file"
	log "INFO" "${module} module mark $mark added to $mark_file"
}

copy_to_binary() {
	local source_file=$1
	local dest_dir=${2:-"/usr/local/bin"}
	if [ ! -f "$source_file" ]; then
		log "ERROR" "Source file $source_file does not exist; cannot move to binary"
		return 1
	fi

	local dest_path="$dest_dir/$(basename "$source_file")"
	if ! sudo install -m 0755 -D "$source_file" "$dest_path"; then
		log "ERROR" "Failed to install binary $source_file to $dest_path"
		return 1
	fi
	log "INFO" "Installed binary $source_file to $dest_path"
	return 0
}
copy_to_config() {
	local source_file=$1
	local sub_dir=${2:-""}
	if [ ! -f "$source_file" ]; then
		log "ERROR" "Source file $source_file does not exist; cannot move to config"
		return 1
	fi

	local destdir="$HOME/.config/$sub_dir"
	# if destdir is a file, error
	if [ -f "$destdir" ]; then
		log "ERROR" "Destination directory $destdir is a file; cannot move config"
		return 1
	fi
	mkdir -p "$destdir"
	rsync -a "$source_file" "$destdir/"
	chmod 644 "$destdir/$(basename "$source_file")"
	log "INFO" "Installed config $source_file to $destdir"
	return 0
}
get_config_dir() {
	local config_dir="$HOME/.config"
	local sub_dir=${1:-""}
	echo "$config_dir/$sub_dir"
}
module_install_callback() {
	local module=$1
	log "VERBOSE" "Running post-install callbacks for module $module"
	local all_modules=()
	for mod_file in "$PROJECT_DIR/modules/"*.sh; do
		mod_name=$(basename "$mod_file" .sh)
		all_modules+=("$mod_name")
	done
	log "DEBUG" "All modules: ${all_modules[*]}"

	# local module_post_reg_func="_${module}_post_install_register"
	# if command -v "$module_post_reg_func" &>/dev/null; then
	# 	log "INFO" "Module $module has a func to register relevant modules post installation."
	# 	"$module_post_reg_func"
	# 	if [ $? -ne 0 ]; then
	# 		log "ERROR" "Module $module failed to run $module_post_reg_func"
	# 		return 1
	# 	fi
	# else
	# 	log "DEBUG" "Module $module has no post installation registration function."
	# fi
	local all_callback_funcs=()
	for mod in "${all_modules[@]}"; do
		if [ "$mod" = "$module" ]; then
			continue
		fi
		local callback_func1="_${mod}_${module}_post_install_callback"
		local callback_func2="_${module}_${mod}_post_install_callback"
		if command -v "$callback_func1" &>/dev/null && ! mark_exists "$callback_func1" && ! mark_exists "$callback_func2" && mark_exists "$mod"; then
			log "INFO" "Module $mod has a post installation callback for $module."
			"$callback_func1"
			if [ $? -ne 0 ]; then
				log "ERROR" "Module $mod failed to run $callback_func1"
				return 1
			fi
			add_mark "$callback_func1"
		fi
		if command -v "$callback_func2" &>/dev/null && ! mark_exists "$callback_func2" && ! mark_exists "$callback_func1" && mark_exists "$mod"; then
			log "INFO" "Module $module has a post installation callback for $mod."
			"$callback_func2"
			if [ $? -ne 0 ]; then
				log "ERROR" "Module $module failed to run $callback_func2"
				return 1
			fi
			add_mark "$callback_func2"
		fi
	done
}

add_mark() {
	local mark=$1
	local mark_file=${2:-"$PROJECT_DIR/run/marks"}
	echo "$mark $(date +%s) # $(date '+%Y-%m-%d %H:%M:%S')" >>"$mark_file"
	log "INFO" "Mark $mark added to $mark_file"
}
mark_older_than() {
	local mark=$1
	local timestamp=$2
	local mark_file="$PROJECT_DIR/run/marks"

	# if mark file doesn't exist, consider it older
	if [ ! -f "$mark_file" ]; then
		log "WARN" "Mark file $mark_file does not exist; considered older"
		touch "$mark_file"
		return 0
	fi

	# if mark doesn't exist in mark file, consider it older
	if grep -Fq "${mark} " "$mark_file"; then
		log "DEBUG" "Mark $mark found in $mark_file"
	else
		log "WARN" "Mark $mark not found in $mark_file; considered older"
		return 0
	fi

	# get the timestamp of the mark in mark_file
	local mark_timestamp
	mark_timestamp=$(grep -F "${mark} " "$mark_file" | awk '{print $2}')
	if [ -z "$mark_timestamp" ]; then
		# mark not found
		log "WARN" "Mark $mark not found; considered older"
		return 0
	fi
	if [ "$mark_timestamp" -lt "$timestamp" ]; then
		log "DEBUG" "Mark $mark timestamp $mark_timestamp is older than $timestamp"
		return 0
	else
		log "DEBUG" "Mark $mark timestamp $mark_timestamp is not older than $timestamp"
		return 1
	fi
}

mark_exists() {
	local mark=$1
	local mark_file=${2:-"$PROJECT_DIR/run/marks"}

	# if mark file doesn't exist, consider mark not exists
	if [ ! -f "$mark_file" ]; then
		log "WARN" "Mark file $mark_file does not exist; mark $mark considered not exists"
		touch "$mark_file"
		return 1
	fi

	# check if mark exists in mark file
	if grep -Fq "${mark} " "$mark_file"; then
		log "DEBUG" "Mark $mark exists in $mark_file"
		return 0
	else
		log "DEBUG" "Mark $mark does not exist in $mark_file"
		return 1
	fi
}

checkout_package_file() {
	local package_name=$1
	local package_file="$PROJECT_DIR/packages/${package_name}.tar.gz"
	# if package file not exists return 1
	if [ ! -f "$package_file" ]; then
		log "ERROR" "Package file $package_file does not exist"
		return 1
	fi

	local destination="$PROJECT_DIR/run/packages/${package_name}"
	
	# Clean up destination if it exists to avoid "File exists" errors from tar
	if [ -d "$destination" ]; then
		rm -rf "$destination" 2>/dev/null || sudo rm -rf "$destination"
	fi
	
	mkdir -p "$destination"

	log "INFO" "Extracting package $package_name to $destination"
	if tar -xzf "$package_file" -C "$destination" 2>&1 >>"$LOG_FILE"; then
		return 0
	else
		log "ERROR" "Failed to extract package $package_file"
		return 1
	fi
}


get_config_dir() {
	local config_dir="$PROJECT_DIR/etc/.config"
	local sub_dir=${1:-""}
	echo "$config_dir/$sub_dir"
}