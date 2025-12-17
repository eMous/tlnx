#!/bin/bash

# Shell-related helpers

# Append raw shell configuration lines into the TLNX-managed block of an rc file.
# The function will manage markers in ~/.zshrc or ~/.bashrc (default) and append
# the provided content just before the block end marker on subsequent calls.
append_shell_rc_block() {
	local content="$1"
	local rc_file="${2:-$(get_rc_file $(get_current_shell))}"
	log "VERBOSE" "Appending content to shell rc file: $rc_file"
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

	awk -v start="$block_start" -v end="$block_end" -v insert_file="$insert_file" '
		BEGIN {
			insert_content = ""
			while ((getline line < insert_file) > 0) {
				insert_content = insert_content line "\n"
			}
			close(insert_file)
			block_len = 0
			inside = 0
		}
		{
			if ($0 == start) {
				print
				inside = 1
				next
			}
			if ($0 == end) {
				# Reconstruct the block without previous copies of insert_content
				block_text = ""
				for (i = 0; i < block_len; i++) {
					block_text = block_text block_lines[i]
				}
				pos = index(block_text, insert_content)
				while (pos) {
					block_text = substr(block_text, 1, pos - 1) substr(block_text, pos + length(insert_content))
					pos = index(block_text, insert_content)
				}
				printf "%s", block_text
				printf "%s", insert_content
				print
				inside = 0
				next
			}
			if (inside) {
				block_lines[block_len++] = $0 "\n"
				next
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
	log "VERBOSE" "Appending sub block ($label) to shell rc file: $rc_file"
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
	log "DEBUG" "Appending sub block ($sub_label) to $rc_file"
	append_shell_rc_block "$block_content" "$rc_file"
}

remove_shell_rc_sub_block() {
	local label="$1"
	local rc_file="${2:-$(get_rc_file $(get_current_shell))}"

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
	local rc_file=$1
	if [ -z "$rc_file" ]; then
		log "ERROR" "rc_file is not set; cannot source rc file"
		return 1
	fi

	if [ -f "$rc_file" ]; then
		log "DEBUG" "Sourcing shell rc file: $rc_file"
		# shellcheck source=/dev/null
		source "$rc_file"
		log "DEBUG" "Sourced shell rc file: $rc_file"
	else
		log "WARN" "Shell rc file not found: $rc_file"
	fi
}

mark_exists() {
	local mark=$1
	local marks_file=${2:-"$TLNX_DIR/run/marks"}
	if grep -Fq "$mark" "$marks_file"; then
		log "DEBUG" "mark $mark found in $marks_file"
		return 0
	else
		log "WARN" "mark $mark not found in $marks_file"
		return 1
	fi
}
check_rcfile() {
	log "INFO" "Checking for existing RC file configurations for CURRENT RUNNING SHELL"
	# considering zsh and bash only for now
	local rc_file=$(get_rc_file $(get_current_shell))
	if [ -z "$rc_file" ]; then
		log "ERROR" "Unable to determine RC file for current shell"
		return 1
	fi
	log "INFO" "Using RC file: $rc_file"
}

get_default_shell() {
	local default_shell
	default_shell=$(getent passwd $(id -un) | cut -d: -f7)
	echo "$default_shell"
}
get_current_shell() {
	local ps_content="$(ps -p $$ -o cmd=)"
	local SHELL_NAME=$(awk '{print $1}' <<<"$ps_content" | xargs basename)
	echo "$SHELL_NAME"
}
get_rc_file() {
	local shell_name=$(basename "$1")
	local rc_file=""
	case "$shell_name" in
	"zsh")
		rc_file="${ZDOTDIR:-$HOME}/.zshrc"
		;;
	"bash")
		rc_file="${BDOTDIR:-$HOME}/.bashrc"
		;;
	*)
		log "WARN" "Unsupported shell $shell_name; cannot determine rc file"
		;;
	esac
	echo "$rc_file"
}
get_home_rc_file() {
	local shell_name=$(basename "$1")
	local rc_file=""
	case "$shell_name" in
	"zsh")
		rc_file="$HOME/.zshrc"
		;;
	"bash")
		rc_file="$HOME/.bashrc"
		;;
	*)
		log "WARN" "Unsupported shell $shell_name; cannot determine rc file"
		;;
	esac
	echo "$rc_file"
}

add_to_path() {
	# if $1 is not a dir, raise an error
	local dir
	eval dir="$1"
	if [ ! -d $dir ]; then
		log "ERROR" "Directory $1 does not exist"
		return 1
	fi

	local content="export PATH=\"$dir:\$PATH\""
	export PATH="$dir:$PATH"
	append_shell_rc_block "$content" "$(get_rc_file zsh)"
	append_shell_rc_block "$content" "$(get_rc_file bash)"
	return 0
}
