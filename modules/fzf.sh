#!/bin/bash

# fzf module - install and configure fzf
# Install fzf
# Module entrypoint for install workflow
_fzf_install() {
	log "INFO" "=== Starting fzf installation and configuration ==="
	if command -v fzf >/dev/null 2>&1; then
		log "INFO" "fzf already installed; skipping installation"
		return 0
	fi

	log "INFO" "Installing fzf..."
	local package_name="fzf"
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

    if [ ! -f "$extracted_dir/$bin_dir/fzf" ]; then
         log "ERROR" "Binary not found: $extracted_dir/$bin_dir/fzf"
         return 1
    fi

	rsync -a "$extracted_dir/$bin_dir/fzf" "$HOME/.local/bin/"
	log "INFO" "=== Finishing fzf installation and configuration ==="
}
