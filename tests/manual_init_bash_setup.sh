#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

export TLNX_DIR="$PROJECT_ROOT"
export HOME="${HOME:-$PROJECT_ROOT}"

mkdir -p "$PROJECT_ROOT/run"
touch "$PROJECT_ROOT/run/marks"

source "$PROJECT_ROOT/lib/common.sh"
source "$PROJECT_ROOT/lib/shell.sh"
source "$PROJECT_ROOT/modules/init.sh"

check_rcfile
init_bash_setup

echo "init_bash_setup completed"
