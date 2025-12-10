#!/bin/bash

# nvim module - install and configure nvim

nvim_install() {
	if command -v nvim >/dev/null 2>&1; then
		log "INFO" "nvim already installed; skipping apt installation"
		return 0
	fi

	log "INFO" "Installing nvim..."
	local package_name="nvim"
	checkout_package_file "$package_name"
	local extracted_dir="$PROJECT_DIR/run/packages/$package_name"
	cd $extracted_dir

	rsync --mkpath -a ./ $HOME/.local/bin/$package_name
	log "INFO" "nvim installed successfully"
}

nvim_configure() {
	log "INFO" "Configuring nvim..."
	# This is handled by init.sh init_conffiles
}

nvim_path_register() {
	local dir="\$HOME/.local/bin/nvim/bin"
	source $PROJECT_DIR/lib/shell.sh
	add_to_path $dir
}

_nvim_install() {
	log "INFO" "=== Starting nvim module ==="
	nvim_install
	nvim_path_register
	nvim_configure
	exit 
	log "INFO" "=== nvim module completed ==="
}
