#!/bin/bash

# Script name: encrypt.sh
# Purpose: encrypt configuration content
# Version: 1.0

# Enable strict mode
set -e

# Usage helper
display_usage() {
	echo "Usage: $0 <source file> [encrypted output file] [key env var]"
	echo "Example 1: $0 config/example.conf config/example.conf.enc" # write to file
	echo "Example 2: $0 config/example.conf"                         # print to stdout
	echo "Or: $0 config/example.conf config/example.conf.enc CUSTOM_KEY_ENV"
	exit 1
}

encrypt() {
	# Validate arguments
	if [ $# -lt 1 ]; then
		display_usage
	fi

	# Collect parameters
	SOURCE_FILE=$1
	OUTPUT_FILE=$2
	DEFAULT_KEY_ENV=${3:-"CONFIG_KEY"}

	# Ensure source file exists
	if [ ! -f "$SOURCE_FILE" ]; then
		echo "Error: source config file not found: $SOURCE_FILE"
		exit 1
	fi

	# Load or prompt for encryption key
	if [ -n "${!DEFAULT_KEY_ENV}" ]; then
		KEY="${!DEFAULT_KEY_ENV}"
		echo "Using key from environment variable $DEFAULT_KEY_ENV" >&2
	else
		while true; do
			read -s -p "Enter encryption key: " KEY
			echo
			read -s -p "Confirm encryption key: " KEY_CONFIRM
			echo
			if [ "$KEY" = "$KEY_CONFIRM" ]; then
				break
			else
				echo "Keys do not match. Please try again."
			fi
		done
	fi

	# Ensure key not empty
	if [ -z "$KEY" ]; then
		echo "Encryption key cannot be empty"
		exit 1
	fi

	# Encrypt using PBKDF2 for safety and to avoid deprecated warnings
	if [ -n "$OUTPUT_FILE" ]; then
		# Write to file
		openssl enc -e -aes-256-cbc -salt -pbkdf2 -in "$SOURCE_FILE" -k "$KEY" >"$OUTPUT_FILE"
		if [ $? -eq 0 ]; then
			echo "Encryption succeeded, written to $OUTPUT_FILE"
			return 0
		else
			echo "Failed to encrypt configuration"
			exit 1
		fi
	else
		# Print to stdout
		openssl enc -e -aes-256-cbc -salt -pbkdf2 -in "$SOURCE_FILE" -k "$KEY"
		if [ $? -eq 0 ]; then
			return 0
		else
			echo "Failed to encrypt configuration"
			exit 1
		fi
	fi
}

