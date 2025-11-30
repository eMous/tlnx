#!/bin/bash

# Shell-related helpers

# Append raw shell configuration lines into the TLNX-managed block of an rc file.
# The function will manage markers in ~/.zshrc or ~/.bashrc (default) and append
# the provided content just before the block end marker on subsequent calls.
append_shell_rc_block() {
	local content="$1"
	local target_shell="${2:-}"

	if [ -z "$content" ]; then
		log "ERROR" "append_shell_rc_block requires content to append"
		return 1
	fi

	local rc_file=""
	case "$target_shell" in
	zsh | ZSH)
		rc_file="$HOME/.zshrc"
		;;
	bash | BASH)
		rc_file="$HOME/.bashrc"
		;;
	/*)
		rc_file="$target_shell"
		;;
	"")
		if [ -f "$HOME/.zshrc" ]; then
			rc_file="$HOME/.zshrc"
		else
			rc_file="$HOME/.bashrc"
		fi
		;;
	*)
		rc_file="$HOME/.${target_shell}"
		;;
	esac

	if [ -z "$rc_file" ]; then
		log "ERROR" "Unable to resolve target shell configuration file"
		return 1
	fi

	if [ ! -e "$rc_file" ]; then
		if ! touch "$rc_file"; then
			log "ERROR" "Failed to create shell configuration file $rc_file"
			return 1
		fi
	fi

	local block_start="# >>> TLNX shell block >>>"
	local block_end="# <<< TLNX shell block <<<"

	if ! grep -Fq "$block_start" "$rc_file"; then
		{
			printf "\n%s\n" "$block_start"
			printf "%s\n" "$content"
			printf "%s\n" "$block_end"
		} >>"$rc_file"
		log "INFO" "Created TLNX shell block in $rc_file"
		return 0
	fi

	if ! grep -Fq "$block_end" "$rc_file"; then
		log "ERROR" "TLNX shell block in $rc_file is missing the end marker"
		return 1
	fi

	local insert_file tmp_file
	insert_file=$(mktemp) || {
		log "ERROR" "Failed to create temporary file for new shell content"
		return 1
	}
	printf "%s\n" "$content" >"$insert_file"

	tmp_file=$(mktemp) || {
		log "ERROR" "Failed to create temporary file for rc rewrite"
		rm -f "$insert_file"
		return 1
	}

	awk -v end="$block_end" -v insert_file="$insert_file" '
        BEGIN {
            insert_content = ""
            while ((getline line < insert_file) > 0) {
                insert_content = insert_content line "\n"
            }
            close(insert_file)
            inserted = 0
        }
        {
            if ($0 == end && !inserted) {
                printf "%s", insert_content
                inserted = 1
            }
            print
        }
    ' "$rc_file" >"$tmp_file"

	if mv "$tmp_file" "$rc_file"; then
		log "INFO" "Appended content to TLNX shell block in $rc_file"
	else
		log "ERROR" "Failed to update $rc_file with new TLNX content"
		rm -f "$tmp_file" "$insert_file"
		return 1
	fi

	rm -f "$insert_file"
	return 0
}

source_rcfile() {
	local shell_name rc_file
	shell_name=$(basename "${SHELL:-/bin/bash}")

	case "$shell_name" in
	bash | sh)
		rc_file="$HOME/.bashrc"
		;;
	zsh)
		rc_file="$HOME/.zshrc"
		;;
	*)
		rc_file="$HOME/.profile"
		;;
	esac

	if [ -f "$rc_file" ]; then
		# shellcheck source=/dev/null
		source "$rc_file"
		log "INFO" "Sourced shell rc file: $rc_file"
	else
		log "WARN" "Shell rc file not found: $rc_file"
	fi
}

init_shell_rc_file() {
	local shell_name rc_file block_start backup_file
	shell_name=$(basename "${SHELL:-/bin/bash}")

	case "$shell_name" in
	bash | sh)
		rc_file="$HOME/.bashrc"
		;;
	zsh)
		rc_file="$HOME/.zshrc"
		;;
	*)
		rc_file="$HOME/.profile"
		;;
	esac

	block_start="# >>> TLNX shell block >>>"
	backup_file="${rc_file}.$(date +%Y%m%d%H%M%S).bak"

	if [ ! -e "$rc_file" ]; then
		: >"$rc_file"
		log "INFO" "Created empty shell rc file: $rc_file"
		return 0
	fi

	if grep -Fq "$block_start" "$rc_file"; then
		log "DEBUG" "TLNX shell block already present in $rc_file"
		return 0
	fi

	# if rc_file is empty do nothing
	if [ ! -s "$rc_file" ]; then
		log "DEBUG" "$rc_file is empty, no backup needed"
		return 0
	fi

	if ! mv "$rc_file" "$backup_file"; then
		log "ERROR" "Failed to back up $rc_file to $backup_file"
		return 1
	fi

	: >"$rc_file"
	log "INFO" "Backed up $rc_file to $backup_file and created a fresh rc file for TLNX configuration"
	return 0
}
