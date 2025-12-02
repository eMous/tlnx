#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

export PROJECT_DIR="$PROJECT_ROOT"

# Use a throwaway HOME so we do not clobber the real ~/.zshrc or oh-my-zsh data.
TEST_HOME="$PROJECT_ROOT/run/tmp/zsh-module-home"
mkdir -p "$TEST_HOME"
export HOME="$TEST_HOME"

mkdir -p "$PROJECT_ROOT/run"
touch "$PROJECT_ROOT/run/marks"

source "$PROJECT_ROOT/lib/common.sh"
source "$PROJECT_ROOT/lib/shell.sh"
source "$PROJECT_ROOT/modules/zsh.sh"

echo "Running ZSH module with PROJECT_DIR=$PROJECT_DIR and HOME=$HOME"
_zsh_install

echo ""
echo "ZSH module finished."
if [ -f "$HOME/.zshrc" ]; then
	echo "Resulting ~/.zshrc:"
	grep -n "ZSH_THEME" "$HOME/.zshrc" || true
else
	echo "No ~/.zshrc was created in $HOME"
fi

echo ""
echo "Log file: $LOG_FILE"
