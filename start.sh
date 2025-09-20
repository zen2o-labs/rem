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

# Single unified configuration file
CONFIG_FILE="$WORKSPACE_DIR/arch-config.txt"

# Default configuration values
DEFAULT_ARCH_ROOT="$WORKSPACE_DIR/arch-root"
DEFAULT_FIXES_DIR="$SCRIPT_DIR/fixes"
DEFAULT_SCRIPTS_DIR="$SCRIPT_DIR/scripts"
DEFAULT_TOOLS_DIR="$WORKSPACE_DIR/tools"
DEFAULT_SCRIPTS_ORDER=(
    "01-install-deps.sh"
    "02-generate-config.sh" 
    "03-setup-bootstrap.sh"
    "04-setup-mounts.sh"
    "05-run-fixes.sh"
    "06-setup-users.sh"
    "07-create-helpers.sh"
)

create_default_config() {
    log "Creating unified configuration file at $CONFIG_FILE"
    
    # Auto-generate secure passwords
    USERNAME="developer"
    USER_PASS=$(openssl rand -base64 12 | tr -d "=+/" | cut -c1-12 2>/dev/null || echo "dev$(date +%s | tail -c 6)")
    ROOT_PASS=$(openssl rand -base64 12 | tr -d "=+/" | cut -c1-12 2>/dev/null || echo "root$(date +%s | tail -c 6)")
    
    cat > "$CONFIG_FILE" << EOF
# Arch Linux Unified Configuration - Generated $(date)
# This file contains both setup parameters and user credentials

# ===== DIRECTORY CONFIGURATION =====
# Repository location (where scripts are located)
SCRIPT_DIR="$SCRIPT_DIR"

# Workspace location (where arch-root and tools will be created) 
WORKSPACE_DIR="$WORKSPACE_DIR"

# Directory where the Arch Linux root filesystem will be created
ARCH_ROOT="$DEFAULT_ARCH_ROOT"

# Directory containing fix scripts
FIXES_DIR="$DEFAULT_FIXES_DIR"

# Directory containing setup scripts
SCRIPTS_DIR="$DEFAULT_SCRIPTS_DIR"

# Directory for tools (created in workspace, not in repo)
TOOLS_DIR="$DEFAULT_TOOLS_DIR"

# ===== SETUP SCRIPT CONFIGURATION =====
# Order of setup scripts to execute (space-separated list)
# You can modify this list to skip or reorder scripts
SETUP_SCRIPTS="01-install-deps.sh 02-generate-config.sh 03-setup-bootstrap.sh 04-setup-mounts.sh 05-run-fixes.sh 06-setup-users.sh 07-create-helpers.sh"

# ===== USER CREDENTIALS =====
# Default user account settings
USERNAME="$USERNAME"
USER_PASS="$USER_PASS"
ROOT_PASS="$ROOT_PASS"

# ===== ADDITIONAL OPTIONS =====
# Add your custom variables below as needed

# Example custom settings (uncomment and modify as needed):
# CUSTOM_PACKAGES="git vim htop neofetch"
# ENABLE_SSH="true"
# TIMEZONE="UTC"
# LOCALE="en_US.UTF-8"
# KEYMAP="us"

# ===== NOTES =====
# - Edit the passwords above and run: ./tools/change-passwords.sh to apply changes
# - Modify SETUP_SCRIPTS to customize which scripts run during setup
# - All paths are auto-detected but can be overridden here
EOF
    
    chmod 600 "$CONFIG_FILE"
    log "✅ Unified configuration file created successfully"
}

load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log "Configuration file not found, creating unified configuration..."
        create_default_config
        return 0
    fi
    
    log "Loading configuration from $CONFIG_FILE"
    
    # Validate config file before sourcing (basic security check)
    if grep -qvE '^[[:space:]]*(#.*)?$|^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=.*$' "$CONFIG_FILE"; then
        log "⚠️  Configuration file contains invalid syntax, recreating..."
        log "Backing up existing config to ${CONFIG_FILE}.backup"
        cp "$CONFIG_FILE" "${CONFIG_FILE}.backup" 2>/dev/null || true
        create_default_config
        return 0
    fi
    
    # Source the config file
    source "$CONFIG_FILE"
    
    # Set defaults for any unset variables
    ARCH_ROOT="${ARCH_ROOT:-$DEFAULT_ARCH_ROOT}"
    FIXES_DIR="${FIXES_DIR:-$DEFAULT_FIXES_DIR}"
    SCRIPTS_DIR="${SCRIPTS_DIR:-$DEFAULT_SCRIPTS_DIR}"
    TOOLS_DIR="${TOOLS_DIR:-$DEFAULT_TOOLS_DIR}"
    
    # Handle SETUP_SCRIPTS - convert space-separated string to array if needed
    if [[ -n "${SETUP_SCRIPTS:-}" ]]; then
        # Convert space-separated string to array
        read -ra SETUP_SCRIPTS_ARRAY <<< "$SETUP_SCRIPTS"
    else
        SETUP_SCRIPTS_ARRAY=("${DEFAULT_SCRIPTS_ORDER[@]}")
    fi
}

# Export for use in other scripts
export WORKSPACE_DIR SCRIPT_DIR

log() {
    echo "[$(date '+%H:%M:%S')] MAIN: $1"
}

show_config() {
    log "Current configuration:"
    log "  Repository location: $SCRIPT_DIR"
    log "  Workspace location: $WORKSPACE_DIR"
    log "  Configuration file: $CONFIG_FILE"
    log "  Arch root will be: $ARCH_ROOT"
    log "  Fixes directory: $FIXES_DIR"
    log "  Scripts directory: $SCRIPTS_DIR"
    log "  Tools directory: $TOOLS_DIR"
    log "  Setup scripts: ${SETUP_SCRIPTS_ARRAY[*]}"
    if [[ -n "${USERNAME:-}" ]]; then
        log "  Username: $USERNAME"
    fi
}

main() {
    log "Starting Arch Linux chroot setup..."
    
    # Load configuration first
    load_config
    
    # Export loaded config values for use in other scripts
    export ARCH_ROOT CONFIG_FILE FIXES_DIR SCRIPTS_DIR TOOLS_DIR WORKSPACE_DIR
    
    # Show current configuration
    show_config
    
    # Create tools directory in workspace (not in repo)
    mkdir -p "$TOOLS_DIR"
    
    # Run scripts in configured order
    for script in "${SETUP_SCRIPTS_ARRAY[@]}"; do
        if [[ -f "$SCRIPTS_DIR/$script" ]]; then
            log "Running $script..."
            bash "$SCRIPTS_DIR/$script"
        else
            log "⚠ Script $script not found in $SCRIPTS_DIR, skipping..."
        fi
    done
    
    log "=== Setup Complete! ==="
    log ""
    log "📁 Locations:"
    log "  Repository: $SCRIPT_DIR"
    log "  Workspace: $WORKSPACE_DIR" 
    log "  Arch root: $ARCH_ROOT"
    log "  Configuration: $CONFIG_FILE"
    log ""
    log "🚀 Run $WORKSPACE_DIR/show-credentials.sh to see login details"
    log ""
    log "💡 To customize setup, edit: $CONFIG_FILE"
}

# Handle command line arguments
case "${1:-}" in
    --show-config)
        load_config
        show_config
        exit 0
        ;;
    --create-config)
        create_default_config
        exit 0
        ;;
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --show-config    Show current configuration and exit"
        echo "  --create-config  Create/recreate unified configuration file and exit"
        echo "  --help, -h       Show this help message"
        echo ""
        echo "Configuration file: $CONFIG_FILE"
        exit 0
        ;;
    "")
        # No arguments, run normally
        main "$@"
        ;;
    *)
        log "Unknown option: $1"
        log "Use --help for available options"
        exit 1
        ;;
esac