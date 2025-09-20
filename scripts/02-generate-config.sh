#!/bin/bash
set -euo pipefail

# Use environment variables from main script
CONFIG_FILE="${CONFIG_FILE:-/workspace/arch-config.txt}"

log() {
    echo "[$(date '+%H:%M:%S')] CONFIG: $1"
}

main() {
    if [[ -f "$CONFIG_FILE" ]]; then
        log "Configuration already exists, skipping generation..."
        return 0
    fi
    
    log "Generating secure configuration at $CONFIG_FILE..."
    
    # Auto-generate secure passwords
    USERNAME="developer"
    USER_PASS=$(openssl rand -base64 12 | tr -d "=+/" | cut -c1-12)
    ROOT_PASS=$(openssl rand -base64 12 | tr -d "=+/" | cut -c1-12)
    
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
}

main "$@"
