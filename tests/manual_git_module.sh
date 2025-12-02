#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

export PROJECT_DIR="$PROJECT_ROOT"

# Use a throwaway HOME so git --global config writes stay inside repo
TEST_HOME="$PROJECT_ROOT/run/tmp/git-module-home"
mkdir -p "$TEST_HOME"
export HOME="$TEST_HOME"

# Ensure marks file exists and force rerun of git module each time
MARK_FILE="$PROJECT_ROOT/run/marks"
mkdir -p "$(dirname "$MARK_FILE")"
touch "$MARK_FILE"
sed -i '/^git-basic-setup$/d' "$MARK_FILE"

# Provide sample Git configuration values for the module
GIT_USER_NAME_X="TLNX Test User"
GIT_USER_EMAIL_X="tlnx-test@example.com"
GIT_CORE_EDITOR="vim"
declare -a GIT_CONFIGS=("pull.ff=only" "color.ui=true")

source "$PROJECT_ROOT/lib/common.sh"
source "$PROJECT_ROOT/lib/shell.sh"
source "$PROJECT_ROOT/modules/git.sh"

echo "Running git module with HOME=$HOME"
_git_install

echo ""
echo "Git module finished."
echo "Global git config written to: $HOME/.gitconfig"
git config --global --list
echo ""
echo "Current run/marks contents:"
cat "$MARK_FILE"
