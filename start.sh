#!/bin/bash
set -euo pipefail

# Auto-detect workspace directory
# If script is in a git repo, use parent directory as workspace
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -d "$SCRIPT_DIR/.git" ]] || git -C "$SCRIPT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
    # We're in a git repo, use parent directory as workspace
    WORKSPACE_DIR="$(dirname "$SCRIPT_DIR")"
    echo "ℹ️  Detected git repository setup"
    echo "ℹ️  Using workspace: $WORKSPACE_DIR"
else
    # We're running directly in workspace
    WORKSPACE_DIR="$SCRIPT_DIR"
fi

# Configuration paths
ARCH_ROOT="$WORKSPACE_DIR/arch-root"
CONFIG_FILE="$WORKSPACE_DIR/arch-config.txt"
FIXES_DIR="$SCRIPT_DIR/fixes"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"
TOOLS_DIR="$WORKSPACE_DIR/tools"

# Export for use in other scripts
export WORKSPACE_DIR ARCH_ROOT CONFIG_FILE SCRIPT_DIR

log() {
    echo "[$(date '+%H:%M:%S')] MAIN: $1"
}

main() {
    log "Starting Arch Linux chroot setup..."
    log "Repository location: $SCRIPT_DIR"
    log "Workspace location: $WORKSPACE_DIR"
    log "Arch root will be: $ARCH_ROOT"
    
    # Create tools directory in workspace (not in repo)
    mkdir -p "$TOOLS_DIR"
    
    # Run scripts in order
    local scripts=(
        "01-install-deps.sh"
        "02-generate-config.sh" 
        "03-setup-bootstrap.sh"
        "04-setup-mounts.sh"
        "05-run-fixes.sh"
        "06-setup-users.sh"
        "07-create-helpers.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [[ -f "$SCRIPTS_DIR/$script" ]]; then
            log "Running $script..."
            bash "$SCRIPTS_DIR/$script"
        else
            log "⚠ Script $script not found, skipping..."
        fi
    done
    
    log "=== Setup Complete! ==="
    log ""
    log "📁 Locations:"
    log "  Repository: $SCRIPT_DIR"
    log "  Workspace: $WORKSPACE_DIR" 
    log "  Arch root: $ARCH_ROOT"
    log "  Config: $CONFIG_FILE"
    log ""
    log "🚀 Run $WORKSPACE_DIR/show-credentials.sh to see login details"
}

main "$@"
