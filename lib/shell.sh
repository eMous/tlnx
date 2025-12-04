#!/bin/bash

# Shell-related helpers



# Append raw shell configuration lines into the TLNX-managed block of an rc file.
# The function will manage markers in ~/.zshrc or ~/.bashrc (default) and append
# the provided content just before the block end marker on subsequent calls.
append_shell_rc_block() {
	local content="$1"
	local rc_file="${2:-${RC_FILE}}"

	if [ -z "$content" ]; then
		log "ERROR" "append_shell_rc_block requires content to append"
		return 1
	fi


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

append_shell_rc_sub_block() {
	local label="$1"
	local content="$2"
	local rc_file="${3:-}"

	if [ -z "$content" ]; then
		log "ERROR" "append_shell_rc_sub_block requires content to append"
		return 1
	fi

	local sub_label="${label:-CUSTOM BLOCK}"
	local sub_start="#     >>> TLNX ${sub_label} >>>"
	local sub_end="#     <<< TLNX ${sub_label} <<<"

	if [ -z "$rc_file" ]; then
		log "ERROR" "Unable to resolve target shell configuration file for sub block"
		return 1
	fi
	if [ ! -e "$rc_file" ] && ! touch "$rc_file"; then
		log "ERROR" "Failed to create shell rc file $rc_file for sub block"
		return 1
	fi

	if grep -Fq "$sub_start" "$rc_file"; then
		local tmp_file
		tmp_file=$(mktemp) || {
			log "ERROR" "Failed to create temporary file for sub block cleanup"
			return 1
		}
		awk -v start="$sub_start" -v end="$sub_end" '
            $0 == start {skip=1; next}
            $0 == end {
                if (skip) {
                    skip=0
                    next
                }
            }
            skip==0 {print}
        ' "$rc_file" >"$tmp_file" && mv "$tmp_file" "$rc_file"
		rm -f "$tmp_file"
	else
		log "DEBUG" "No existing TLNX sub block ($sub_label) found in $rc_file; nothing to replace"
	fi

	local block_content
	block_content=$(printf "%s\n%s\n%s" "$sub_start" "$content" "$sub_end")
	append_shell_rc_block "$block_content" "$rc_file"
}

remove_shell_rc_sub_block() {
	local label="$1"
	local rc_file="${2:-${RC_FILE}}"

	if [ -z "$label" ]; then
		log "ERROR" "remove_shell_rc_sub_block requires a label"
		return 1
	fi

	local sub_start="#     >>> TLNX ${label} >>>"
	local sub_end="#     <<< TLNX ${label} <<<"

	if [ -z "$rc_file" ]; then
		log "ERROR" "Unable to resolve target shell configuration file for sub block removal"
		return 1
	fi

	if [ ! -e "$rc_file" ]; then
		log "WARN" "Shell rc file $rc_file does not exist; nothing to remove"
		return 0
	fi

	if ! grep -Fq "$sub_start" "$rc_file"; then
		log "DEBUG" "No TLNX sub block ($label) found in $rc_file; nothing to remove"
		return 0
	fi

	local tmp_file
	tmp_file=$(mktemp) || {
		log "ERROR" "Failed to create temporary file for sub block removal"
		return 1
	}

	awk -v start="$sub_start" -v end="$sub_end" '
		$0 == start {skip=1; next}
		$0 == end {
			if (skip) {
				skip=0
				next
			}
		}
		skip==0 {print}
	' "$rc_file" >"$tmp_file" && mv "$tmp_file" "$rc_file"

	rm -f "$tmp_file"
	log "INFO" "Removed TLNX sub block ($label) from $rc_file"
	return 0
}

source_rcfile() {
	local rc_file="${RC_FILE:-}"
	if [ -z "$rc_file" ]; then
		log "ERROR" "RC_FILE is not set; cannot source rc file"
		return 1
	fi

	if [ -f "$rc_file" ]; then
		log "VERBOSE" "Sourcing shell rc file: $rc_file"
		# shellcheck source=/dev/null
		source "$rc_file"
		log "INFO" "Sourced shell rc file: $rc_file"
	else
		log "WARN" "Shell rc file not found: $rc_file"
	fi
}

init_shell_rc_file() {
	local rc_file="${RC_FILE:-}" block_start backup_file
	log "VERBOSE" "Initializing shell rc file: $rc_file"
	if [ -z "$rc_file" ]; then
		log "ERROR" "RC_FILE is not set; cannot initialize rc file"
		return 1
	fi

	block_start="# >>> TLNX shell block >>>"
	backup_file="${rc_file}.$(date +%Y%m%d%H%M%S).bak"

	if [ ! -e "$rc_file" ]; then
		: >"$rc_file"
		log "INFO" "Created empty shell rc file: $rc_file"
		return 0
	fi

	if grep -Fq "$block_start" "$rc_file"; then
		log "DEBUG" "TLNX shell block already present in $rc_file"
		source_rcfile
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

check_rcfile() {
	log "INFO" "Checking for existing RC file configurations"
	# considering zsh and bash only for now
	local SHELL_NAME
	SHELL_NAME=$(basename "$SHELL")
	RC_FILE=""
	if [ "$SHELL_NAME" = "zsh" ]; then
		RC_FILE="$HOME/.zshrc"
	elif [ "$SHELL_NAME" = "bash" ]; then
		RC_FILE="$HOME/.bashrc"
	else
		log "WARN" "Unsupported shell $SHELL_NAME, skipping RC file check"
		return 1
	fi
	log "INFO" "Using RC file: $RC_FILE"
}

get_default_shell() {
	local default_shell
	default_shell=$(getent passwd "$USER" | cut -d: -f7)
	echo "$default_shell"
}

mark_exists() {
	local mark=$1
	local marks_file=${2:-"$PROJECT_DIR/run/marks"}
	if grep -Fq "$mark" "$marks_file"; then
		log "DEBUG" "mark $mark found in $marks_file"
		return 0
	else
		log "WARN" "mark $mark not found in $marks_file"
		return 1
	fi
}