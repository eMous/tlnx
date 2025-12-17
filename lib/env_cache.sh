#!/bin/bash

# Environment variable caching helpers

ENV_CACHE_FILE="$TLNX_DIR/run/env.cache"

# Save current environment variables to cache file
save_env_cache() {
	mkdir -p "$(dirname "$ENV_CACHE_FILE")"
	
	# We only want to save variables that are relevant to configuration.
	# Saving everything (export -p) is safest but might be noisy.
	# Let's save everything for now to ensure we catch all potential dependencies.
	# We filter out some obviously dynamic or internal variables to reduce noise.
	
	export -p | grep -vE "^declare -x (BASH|SHELL|PWD|OLDPWD|SHLVL|_|LS_COLORS|XDG_|SSH_|TERM|USER|HOME|PATH|LOG_|TLNX_DIR|TLNX_ORIGINAL_ARGS)" > "$ENV_CACHE_FILE"
	
	log "DEBUG" "Environment variables cached to $ENV_CACHE_FILE"
}

# Get the value of a variable from the cache file
# Usage: get_cached_env_value VAR_NAME
get_cached_env_value() {
	local var_name="$1"
	if [ ! -f "$ENV_CACHE_FILE" ]; then
		return 1
	fi
	
	# Extract value from export -p format: declare -x VAR="VALUE"
	# We use grep to find the line, then sed to extract the value.
	# Note: This is a simple parser and might fail on multi-line values, 
	# but config vars are usually single line.
	
	local line
	line=$(grep -E "^declare -x ${var_name}=" "$ENV_CACHE_FILE" | tail -n 1)
	
	if [ -z "$line" ]; then
		return 1
	fi
	
	# Remove 'declare -x VAR='
	local value="${line#*${var_name}=}"
	
	# Remove surrounding quotes if present (export -p usually quotes)
	# But wait, if we just source the file in a subshell and echo the var, it's safer.
	
	(
		source "$ENV_CACHE_FILE"
		echo "${!var_name}"
	)
}
