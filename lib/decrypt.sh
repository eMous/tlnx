#!/bin/bash

# Decrypt configuration script - outputs to file or stdout

decrypt () {
	# Argument validation
	if [ $# -lt 1 ]; then
		echo "Usage: $0 <encrypted file> [output file] [key env var]"
		echo "Example 1: $0 config/enc.conf.enc config/enc.conf" # write to file
		echo "Example 2: $0 config/enc.conf.enc"                 # print to stdout
		exit 1
	fi

	# Encrypted file path
	ENCRYPTED_FILE="$1"

	# Optional decrypted output
	OUTPUT_FILE="$2"

	# Default key env var name
	DEFAULT_KEY_ENV=${3:-"CONFIG_KEY"}

	# Load key from env var or prompt user
	if [ -n "${!DEFAULT_KEY_ENV}" ]; then
		KEY="${!DEFAULT_KEY_ENV}"
		echo "Using key from environment variable $DEFAULT_KEY_ENV" >&2
	else
		read -s -p "Enter decryption key: " KEY
		echo
	fi

	# Ensure key is not empty
	if [ -z "$KEY" ]; then
		echo "Decryption key cannot be empty"
		exit 1
	fi

	# Decrypt via openssl
	if [ -n "$OUTPUT_FILE" ]; then
		# Write to file
		openssl enc -d -aes-256-cbc -salt -pbkdf2 -in "$ENCRYPTED_FILE" -k "$KEY" >"$OUTPUT_FILE"
		if [ $? -eq 0 ]; then
			echo "Decryption succeeded, written to $OUTPUT_FILE"
		else
			echo "Decryption failed"
			exit 1
		fi
	else
		# Print to stdout
		openssl enc -d -aes-256-cbc -salt -pbkdf2 -in "$ENCRYPTED_FILE" -k "$KEY"
		if [ $? -eq 0 ]; then
			return 0
		else
			exit 1
		fi
	fi
}



