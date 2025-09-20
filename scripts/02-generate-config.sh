#!/bin/bash
set -euo pipefail

# Use environment variables from main script
CONFIG_FILE="${CONFIG_FILE:-$WORKSPACE_DIR/arch-config.txt}"

log() {
    echo "[$(date '+%H:%M:%S')] CONFIG: $1"
}

main() {
    if [[ -f "$CONFIG_FILE" ]]; then
        log "Configuration already exists, skipping generation..."
        return 0
    fi
    
    log "Generating configuration at $CONFIG_FILE..."
    
    # Use environment variables if provided, otherwise generate
    USERNAME="${ARCH_USERNAME:-developer}"
    USER_PASS="${ARCH_USER_PASSWORD:-$(openssl rand -base64 12 | tr -d '=+/' | cut -c1-12)}"
    ROOT_PASS="${ARCH_ROOT_PASSWORD:-$(openssl rand -base64 12 | tr -d '=+/' | cut -c1-12)}"
    
    # Save configuration with repository info
    cat > "$CONFIG_FILE" << EOF
# Arch Linux Configuration - Generated $(date)
# Repository: $SCRIPT_DIR
# Workspace: $WORKSPACE_DIR

USERNAME="$USERNAME"
USER_PASS="$USER_PASS"
ROOT_PASS="$ROOT_PASS"

# Directory locations (auto-detected)
WORKSPACE_DIR="$WORKSPACE_DIR"
ARCH_ROOT="$ARCH_ROOT"
SCRIPT_DIR="$SCRIPT_DIR"

# Edit these values and run $WORKSPACE_DIR/tools/change-passwords.sh to apply changes
EOF
    
    chmod 600 "$CONFIG_FILE"
    log "✓ Configuration generated at $CONFIG_FILE"
    
    if [[ -n "${ARCH_USER_PASSWORD:-}" ]]; then
        log "✓ Using provided user password"
    else
        log "✓ Generated user password: $USER_PASS"
    fi
    
    if [[ -n "${ARCH_ROOT_PASSWORD:-}" ]]; then
        log "✓ Using provided root password"
    else
        log "✓ Generated root password: $ROOT_PASS"
    fi
}

main "$@"
