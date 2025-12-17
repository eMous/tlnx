#!/bin/bash

# Version helper utilities

: "${DEFAULT_CONFIG_FILE:=${TLNX_DIR:+${TLNX_DIR}/}config/default.conf}"

# Compare two semantic version strings.
# Returns: 0 when equal, 1 when first argument is newer, 2 when first argument is older.
compare_versions() {
	local version_a="$1"
	local version_b="$2"

	if [ -z "$version_a" ] || [ -z "$version_b" ]; then
		_version_log "ERROR" "compare_versions requires two version strings"
		return 3
	fi

	local IFS='.'
	read -ra parts_a <<<"$version_a"
	read -ra parts_b <<<"$version_b"

	local max_len=${#parts_a[@]}
	if [ ${#parts_b[@]} -gt $max_len ]; then
		max_len=${#parts_b[@]}
	fi

	for ((i = 0; i < max_len; i++)); do
		local val_a=$((10#${parts_a[$i]:-0}))
		local val_b=$((10#${parts_b[$i]:-0}))

		if ((val_a > val_b)); then
			return 1
		elif ((val_a < val_b)); then
			return 2
		fi
	done

	return 0
}

# Read the VERSION entry from the provided config file.
get_config_version() {
	local config_file="${1:-${DEFAULT_CONFIG_FILE}}"
	if [ ! -f "$config_file" ]; then
		log "ERROR" "Config file not found: $config_file"
		return 1
	fi

	local version_line version
	version_line=$(grep -m1 '^VERSION=' "$config_file")
	if [ -z "$version_line" ]; then
		log "ERROR" "VERSION entry missing in $config_file"
		return 1
	fi

	version=${version_line#VERSION=}
	version=${version//\"/}
	version=${version//\'/}
	version=$(echo "$version" | tr -d ' ')

	if [ -z "$version" ]; then
		log "ERROR" "Unable to parse VERSION from $config_file"
		return 1
	fi

	printf '%s\n' "$version"
	return 0
}

# Increment the project version stored in config/default.conf.
# Usage: bump_version small|middle|large [path_to_default_conf]
bump_version() {
	local level="$1"
	local config_file="${2:-${DEFAULT_CONFIG_FILE}}"

	if [ -z "$level" ]; then
		log "ERROR" "bump_version requires a level: small, middle, or large"
		return 1
	fi

	if [ ! -f "$config_file" ]; then
		log "ERROR" "Config file not found for version update: $config_file"
		return 1
	fi

	local current_version
	if ! current_version=$(get_config_version "$config_file"); then
		log "ERROR" "Cannot determine current version from $config_file"
		return 1
	fi

	local IFS='.'
	read -r major minor patch <<<"$current_version"
	major=${major:-0}
	minor=${minor:-0}
	patch=${patch:-0}

	case "$level" in
	small | patch)
		patch=$((patch + 1))
		;;
	middle | minor)
		minor=$((minor + 1))
		patch=0
		;;
	large | major)
		major=$((major + 1))
		minor=0
		patch=0
		;;
	*)
		log "ERROR" "Unknown version level: $level"
		return 1
		;;
	esac

	local new_version="${major}.${minor}.${patch}"

	local tmp_file
	tmp_file=$(mktemp) || {
		log "ERROR" "Failed to create temporary file for version update"
		return 1
	}

	awk -v new_version="$new_version" '
        BEGIN {updated=0}
        /^TLXN_VERSION=/ {
            print "TLXN_VERSION=\"" new_version "\""
            updated=1
            next
        }
        {print}
        END {
            if (updated==0) {
                printf "\nTLXN_VERSION=\"%s\"\n", new_version
            }
        }
    ' "$config_file" >"$tmp_file"

	if [ $? -ne 0 ]; then
		rm -f "$tmp_file"
		log "ERROR" "Failed to render updated config with new version"
		return 1
	fi

	if ! mv "$tmp_file" "$config_file"; then
		rm -f "$tmp_file"
		log "ERROR" "Failed to overwrite $config_file with new version"
		return 1
	fi

	TLXN_VERSION="$new_version"
	export TLXN_VERSION
	log "INFO" "Version bumped to $new_version in $config_file"
	return 0
}
