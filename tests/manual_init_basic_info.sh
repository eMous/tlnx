#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

export PROJECT_DIR="$PROJECT_ROOT"

source "$PROJECT_ROOT/lib/common.sh"
source "$PROJECT_ROOT/lib/shell.sh"
source "$PROJECT_ROOT/lib/prerequisite.sh"
source "$PROJECT_ROOT/lib/config.sh"
source "$PROJECT_ROOT/modules/init.sh"
init_network_info
