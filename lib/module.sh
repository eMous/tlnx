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
	local index=${3:-0}
	local total=${4:-0}
	log "INFO" "===== Executing module: $module ($index/$total) ====="
	if [ -f "$TLNX_DIR/modules/$module.sh" ]; then
		source "$TLNX_DIR/modules/$module.sh"
		local mark="${module}_installed_mark"
		local marks_file="$TLNX_DIR/run/marks"
		local need_install=true

		if [ "$force" != "true" ]; then
			local check_func="_${module}_check_installed"
			if command -v "$check_func" &>/dev/null; then
				if "$check_func" "${module}" "${mark}" "${marks_file}"; then
					log "INFO" "Module $module passed specific check; skipping installation"
					need_install=false
				else
					log "INFO" "Module $module failed specific check; starting installation"
					need_install=true
				fi
			else
				log "INFO" "Module $module not installed; starting installation"
				need_install=true
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
						log "ERROR" "===== Module $module is required and failed to install; aborting ====="
						exit 1
					fi
					log "ERROR" "===== Module $module failed to run $install_func ====="
					return 1
				fi
				module_install_callback "${module}"
				# module_install_complete "${module}" "${mark}" "${marks_file}"
			else
				log "WARN" "===== Module $module is missing ${install_func}; Check again.. ====="
				exit 1
			fi
		fi

		log "INFO" "===== Module $module ($index/$total) completed ====="
	else
		log "WARN" "===== Module script missing: modules/$module.sh; Check again.. ====="
		exit 1
	fi
}

# module_install_complete() {
	# local off_mark_control=("${OFF_MARK_CONTROL[@]}")
	# local module=$1
	# local mark=$2
	# local mark_file=$3
	# # if module is not in off_mark_control list add the mark
	# if [[ " ${off_mark_control[*]} " == *" $module "* ]]; then
		# log "INFO" "${module} module is in off_mark_control list; skipping mark addition"
		# return 0
	# fi
	# # Add the mark
	# add_mark "$mark" "$mark_file"
	# log "INFO" "${module} module mark $mark added to $mark_file"
# }

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
	local all_installed_modules=()
	for mod_file in "$TLNX_DIR/modules/"*.sh; do
		mod_name=$(basename "$mod_file" .sh)
		if _${mod_name}_check_installed &>/dev/null; then
			all_installed_modules+=("$mod_name")
		fi
	done
	log "DEBUG" "All installed modules: ${all_installed_modules[*]}"
	local all_callback_funcs=()
	for mod in "${all_installed_modules[@]}"; do
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
	local mark_file=${2:-"$TLNX_DIR/run/marks"}
	echo "$mark $(date +%s) # $(date '+%Y-%m-%d %H:%M:%S')" >>"$mark_file"
	log "INFO" "Mark $mark added to $mark_file"
}
mark_older_than() {
	local mark=$1
	local timestamp=$2
	local mark_file="$TLNX_DIR/run/marks"

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
	local mark_file=${2:-"$TLNX_DIR/run/marks"}

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

install_package_binary() {
	local module=$1
	local binary_name=${2:-$module}
	local relative_path=${3:-""}

	local arch
	arch=$(uname -m)
	local arch_dir
	case "$arch" in
	x86_64) arch_dir="amd64" ;;
	aarch64) arch_dir="arm64" ;;
	*)
		log "ERROR" "Unsupported architecture: $arch"
		return 1
		;;
	esac

	local src_base="$TLNX_DIR/packages/$module"
	local src=""

	# Try arch specific first
	if [ -f "$src_base/$arch_dir/$binary_name" ]; then
		src="$src_base/$arch_dir/$binary_name"
	elif [ -f "$src_base/$arch_dir/$relative_path/$binary_name" ]; then
		src="$src_base/$arch_dir/$relative_path/$binary_name"
	# Fallback to root if no arch dir
	elif [ -f "$src_base/$binary_name" ]; then
		src="$src_base/$binary_name"
	else
		log "ERROR" "Binary $binary_name not found in $src_base for arch $arch"
		return 1
	fi

	local bin_dir="$TLNX_DIR/run/bin"
	mkdir -p "$bin_dir"

	local dest="$bin_dir/$binary_name"

	# Create symlink
	if [ -L "$dest" ] && [ "$(readlink -f "$dest")" = "$(readlink -f "$src")" ]; then
		log "INFO" "$dest is already linked to $src; skipping"
	else
		ln -sf "$src" "$dest"
		log "INFO" "Linked $src to $dest"
	fi

	# Also link to $HOME/.local/bin
	local user_bin_dir="$HOME/.local/bin"
	mkdir -p "$user_bin_dir"
	local user_dest="$user_bin_dir/$binary_name"

	if [ -L "$user_dest" ] && [ "$(readlink -f "$user_dest")" = "$(readlink -f "$src")" ]; then
		log "INFO" "$user_dest is already linked to $src; skipping"
	else
		ln -sf "$src" "$user_dest"
		log "INFO" "Linked $src to $user_dest"
	fi
}


get_config_dir() {
	local config_dir="$TLNX_DIR/etc/.config"
	local sub_dir=${1:-""}
	echo "$config_dir/$sub_dir"
}