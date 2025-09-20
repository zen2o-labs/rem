#!/bin/bash
# /rem/scripts/05-run-fixes.sh
set -euo pipefail

# Use environment variables from main script
FIXES_DIR="${FIXES_DIR:-${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/fixes}"
ARCH_ROOT="${ARCH_ROOT:-${WORKSPACE_DIR:-$(pwd)}/arch-root}"
CONFIG_FILE="${CONFIG_FILE:-${WORKSPACE_DIR:-$(pwd)}/arch-config.txt}"
WORKSPACE_DIR="${WORKSPACE_DIR:-$(pwd)}"
SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

log() {
    echo "[$(date '+%H:%M:%S')] FIXES: $1"
}

main() {
    log "Running container compatibility fixes..."
    log "Fixes directory: $FIXES_DIR"
    
    local fixes=(
        "fix-ssl-certs.sh"
        "fix-dev-fd.sh" 
        "fix-mtab.sh"
        "fix-network.sh"
        "fix-pacman.sh"
        "fix-essential-devices.sh"
        "fix-sudo-permissions.sh" 
    )
    
    for fix in "${fixes[@]}"; do
        if [[ -f "$FIXES_DIR/$fix" ]]; then
            log "Applying $fix..."
            # Export environment variables for fix scripts
            export ARCH_ROOT CONFIG_FILE WORKSPACE_DIR SCRIPT_DIR FIXES_DIR
            bash "$FIXES_DIR/$fix"
        else
            log "⚠ Fix $fix not found at $FIXES_DIR/$fix, skipping..."
        fi
    done
    
    log "✓ All fixes applied"
}

main "$@"