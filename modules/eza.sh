#!/bin/bash

# eza module - install and configure eza
# Install eza
# Module entrypoint for install workflow
_eza_install() {
	log "INFO" "=== Starting eza installation and configuration ==="
	if command -v eza >/dev/null 2>&1; then
		log "INFO" "eza already installed; skipping installation"
		return 0
	fi

	log "INFO" "Installing eza..."
	local package_name="eza"
	if ! checkout_package_file "$package_name"; then
		log "ERROR" "Failed to checkout package file for $package_name"
		return 1
	fi

	local extracted_dir="$PROJECT_DIR/run/packages/$package_name"
    
    local arch
    arch=$(uname -m)
    local bin_dir
    case "$arch" in
        x86_64) bin_dir="amd64" ;;
        aarch64) bin_dir="arm64" ;;
        *)
            log "ERROR" "Unsupported architecture: $arch"
            return 1
            ;;
    esac

    if [ ! -f "$extracted_dir/$bin_dir/eza" ]; then
         log "ERROR" "Binary not found: $extracted_dir/$bin_dir/eza"
         return 1
    fi

	rsync -a "$extracted_dir/$bin_dir/eza" "$HOME/.local/bin/"
	log "INFO" "=== Finishing eza installation and configuration ==="
}
