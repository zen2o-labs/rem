#!/bin/bash
# /rem/scripts/02-generate-config.sh
set -euo pipefail

# Use environment variables from main script - these should be exported by start.sh
CONFIG_FILE="${CONFIG_FILE:-${WORKSPACE_DIR:-$(pwd)}/arch-config.txt}"
WORKSPACE_DIR="${WORKSPACE_DIR:-$(pwd)}"
ARCH_ROOT="${ARCH_ROOT:-${WORKSPACE_DIR}/arch-root}"
SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

log() {
    echo "[$(date '+%H:%M:%S')] CONFIG: $1"
}

main() {
    # Check if unified config already exists and has credentials
    if [[ -f "$CONFIG_FILE" ]]; then
        # Check if the config file already has USERNAME, USER_PASS, and ROOT_PASS
        if grep -q "^USERNAME=" "$CONFIG_FILE" && \
           grep -q "^USER_PASS=" "$CONFIG_FILE" && \
           grep -q "^ROOT_PASS=" "$CONFIG_FILE"; then
            log "Unified configuration with credentials already exists, skipping generation..."
            return 0
        fi
    fi
    
    log "Configuration validation completed - unified config is ready"
    log "Using configuration file: $CONFIG_FILE"
    
    # The unified config is already created by start.sh, so we just validate it exists
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log "ERROR: Configuration file should have been created by start.sh but is missing!"
        exit 1
    fi
    
    log "✓ Configuration validated successfully"
}

main "$@"