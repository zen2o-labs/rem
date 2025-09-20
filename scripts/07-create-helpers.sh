#!/bin/bash
# /rem/scripts/07-create-helpers.sh
set -euo pipefail

# Use environment variables from main script
TOOLS_DIR="${TOOLS_DIR:-${WORKSPACE_DIR:-$(pwd)}/tools}"
WORKSPACE_DIR="${WORKSPACE_DIR:-$(pwd)}"
ARCH_ROOT="${ARCH_ROOT:-${WORKSPACE_DIR}/arch-root}"
CONFIG_FILE="${CONFIG_FILE:-${WORKSPACE_DIR}/arch-config.txt}"
SCRIPT_DIR="${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

log() {
    echo "[$(date '+%H:%M:%S')] HELPERS: $1"
}

main() {
    log "Creating helper scripts in $TOOLS_DIR..."
    log "Workspace directory: $WORKSPACE_DIR"
    log "Arch root directory: $ARCH_ROOT"
    log "Config file: $CONFIG_FILE"
    
    # Load config to get username (if available)
    local USERNAME="developer"  # default
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    fi
    
    # Create tools directory
    mkdir -p "$TOOLS_DIR"
    
    # Main entry scripts - FIXED: Use absolute path to config file
    cat > "$WORKSPACE_DIR/enter-arch.sh" << ENTEREOF
#!/bin/bash
set -euo pipefail

# Use absolute path to config file in workspace, not relative to script location
CONFIG_FILE="$CONFIG_FILE"

[[ ! -f "\$CONFIG_FILE" ]] && { 
    echo "ERROR: Config not found at \$CONFIG_FILE"
    echo "Run: ./rem/start.sh to create configuration"
    exit 1
}

source "\$CONFIG_FILE"

[[ ! -d "\$ARCH_ROOT" ]] && { 
    echo "ERROR: Arch root not found at \$ARCH_ROOT. Run setup first."
    exit 1
}

exec chroot "\$ARCH_ROOT" /usr/bin/bash -l
ENTEREOF
    chmod +x "$WORKSPACE_DIR/enter-arch.sh"
    
    cat > "$WORKSPACE_DIR/enter-arch-user.sh" << ENTERUSEREOF
#!/bin/bash
set -euo pipefail

# Use absolute path to config file in workspace, not relative to script location
CONFIG_FILE="$CONFIG_FILE"

[[ ! -f "\$CONFIG_FILE" ]] && { 
    echo "ERROR: Config not found at \$CONFIG_FILE"
    echo "Run: ./rem/start.sh to create configuration"
    exit 1
}

source "\$CONFIG_FILE"

[[ ! -d "\$ARCH_ROOT" ]] && { 
    echo "ERROR: Arch root not found at \$ARCH_ROOT"
    exit 1
}

[[ ! -d "\$ARCH_ROOT/home/\$USERNAME" ]] && { 
    echo "ERROR: User home not found at \$ARCH_ROOT/home/\$USERNAME"
    exit 1
}

echo "Entering Arch Linux as user: \$USERNAME"
exec chroot "\$ARCH_ROOT" su -l "\$USERNAME"
ENTERUSEREOF
    chmod +x "$WORKSPACE_DIR/enter-arch-user.sh"
    
    # Package installer - FIXED: Use absolute path
    cat > "$TOOLS_DIR/install-packages.sh" << PKGEOF
#!/bin/bash
set -euo pipefail

# Use absolute path to config file
CONFIG_FILE="$CONFIG_FILE"

[[ ! -f "\$CONFIG_FILE" ]] && { 
    echo "ERROR: Config not found at \$CONFIG_FILE"
    exit 1
}

source "\$CONFIG_FILE"

if [[ \$# -eq 0 ]]; then
    echo "Usage: \$0 <package1> [package2] [...]"
    echo "Example: \$0 git vim python nodejs"
    exit 1
fi

echo "📦 Installing packages: \$*"
chroot "\$ARCH_ROOT" /usr/bin/bash -c "
    pacman -Sy --noconfirm >/dev/null 2>&1
    pacman -S --noconfirm --overwrite '*' \$* && echo '✅ Installation completed!'
"
PKGEOF
    chmod +x "$TOOLS_DIR/install-packages.sh"
    
    # Credentials display - FIXED: Use absolute path
    cat > "$WORKSPACE_DIR/show-credentials.sh" << CREDSEOF
#!/bin/bash

# Use absolute path to config file
CONFIG_FILE="$CONFIG_FILE"

echo "=== Arch Linux Chroot Credentials ==="
echo ""

[[ ! -f "\$CONFIG_FILE" ]] && { 
    echo "❌ Config not found at \$CONFIG_FILE"
    echo "Run: ./rem/start.sh to create configuration"
    exit 1
}

source "\$CONFIG_FILE"

echo "📁 Workspace: \$WORKSPACE_DIR"
echo "🐧 Arch root: \$ARCH_ROOT"
echo "📄 Config: \$CONFIG_FILE"
echo ""
echo "🔐 Root Access:"
echo "  Username: root"  
echo "  Password: \$ROOT_PASS"
echo "  Command:  ./enter-arch.sh"
echo ""
echo "👤 User Access:"
echo "  Username: \$USERNAME"
echo "  Password: \$USER_PASS"
echo "  Command:  ./enter-arch-user.sh"
echo "  Sudo: Yes (passwordless)"
echo ""
echo "🛠️ Tools:"
echo "  ./tools/install-packages.sh <pkg>  - Install packages"
echo "  ./tools/quick-setup.sh             - Install essentials"
CREDSEOF
    chmod +x "$WORKSPACE_DIR/show-credentials.sh"
    
    # Quick setup
    cat > "$TOOLS_DIR/quick-setup.sh" << 'QUICKEOF'
#!/bin/bash
set -euo pipefail

echo "🚀 Quick Arch Linux Setup"
echo ""

"$(dirname "${BASH_SOURCE[0]}")/install-packages.sh" \
    base-devel git wget curl nano vim sudo python htop tree fastfetch

echo ""
echo "✅ Quick setup completed!"
echo "Next: ../enter-arch-user.sh"
QUICKEOF
    chmod +x "$TOOLS_DIR/quick-setup.sh"
    
    # Development setup
    cat > "$TOOLS_DIR/dev-setup.sh" << 'DEVEOF'
#!/bin/bash
set -euo pipefail

echo "🔧 Development Environment Setup"
echo ""

"$(dirname "${BASH_SOURCE[0]}")/install-packages.sh" \
    base-devel git nodejs npm python python-pip \
    docker kubectl helm terraform ansible \
    neovim tmux zsh fish starship

echo ""
echo "✅ Development environment ready!"
echo "Consider: chsh -s /usr/bin/zsh (in Arch)"
DEVEOF
    chmod +x "$TOOLS_DIR/dev-setup.sh"
    
    # System dashboard - FIXED: Use absolute path
    cat > "$TOOLS_DIR/dashboard.sh" << DASHEOF
#!/bin/bash

# Use absolute path to config file
CONFIG_FILE="$CONFIG_FILE"

echo "🖥️  Arch Linux Chroot Dashboard"
echo "=============================="
echo ""

if [[ -f "\$CONFIG_FILE" ]]; then
    source "\$CONFIG_FILE"
    echo "✅ Configuration: Loaded"
    echo "📁 Workspace: \$WORKSPACE_DIR"
    echo "🐧 Arch root: \$ARCH_ROOT"
    echo "👤 Username: \$USERNAME"
    
    if [[ -d "\$ARCH_ROOT" ]]; then
        echo "✅ Arch Environment: Ready"
        
        # Show installed packages count
        pkg_count=\$(chroot "\$ARCH_ROOT" pacman -Q 2>/dev/null | wc -l)
        echo "📦 Packages: \$pkg_count installed"
        
        # Show disk usage
        arch_size=\$(du -sh "\$ARCH_ROOT" 2>/dev/null | cut -f1)
        echo "💾 Size: \$arch_size"
        
        # Test user access
        if chroot "\$ARCH_ROOT" id "\$USERNAME" >/dev/null 2>&1; then
            echo "👤 User: \$USERNAME (ready)"
        else
            echo "❌ User: Issues detected"
        fi
    else
        echo "❌ Arch Environment: Not found"
    fi
else
    echo "❌ Configuration: Not found at \$CONFIG_FILE"
    echo "Run: ./rem/start.sh"
fi

echo ""
echo "🔗 Quick Commands:"
echo "  ./enter-arch-user.sh     - Enter as user"
echo "  ./tools/quick-setup.sh   - Install essentials"  
echo "  ./show-credentials.sh    - View passwords"
DASHEOF
    chmod +x "$TOOLS_DIR/dashboard.sh"
    
    # Debug script - FIXED: Use absolute path
    cat > "$WORKSPACE_DIR/debug-setup.sh" << DEBUGEOF
#!/bin/bash

echo "🔍 Arch Chroot Debug"
echo "===================="
echo ""

# Use absolute path to config file
CONFIG_FILE="$CONFIG_FILE"

echo "📁 Current: \$(pwd)"
echo "📄 Looking for config: \$CONFIG_FILE"
echo ""

if [[ -f "\$CONFIG_FILE" ]]; then
    echo "✅ Config found"
    source "\$CONFIG_FILE"
    
    [[ -d "\$ARCH_ROOT" ]] && echo "✅ Arch root exists" || echo "❌ Arch root missing"
    [[ -d "\$ARCH_ROOT/home/\$USERNAME" ]] && echo "✅ User home exists" || echo "❌ User home missing"
    
    echo ""
    echo "🔧 Next steps:"
    if [[ ! -d "\$ARCH_ROOT" ]]; then
        echo "   ./rem/start.sh"
    elif [[ ! -d "\$ARCH_ROOT/home/\$USERNAME" ]]; then
        echo "   ./rem/scripts/06-setup-users.sh"
    else
        echo "   ./enter-arch-user.sh"
    fi
else
    echo "❌ Config missing at \$CONFIG_FILE"
    echo "🔧 Run: ./rem/start.sh"
fi
DEBUGEOF
    chmod +x "$WORKSPACE_DIR/debug-setup.sh"
    
    # Change passwords script - FIXED: Use absolute path
    cat > "$TOOLS_DIR/change-passwords.sh" << CHPWDEOF
#!/bin/bash
set -euo pipefail

# Use absolute path to config file
CONFIG_FILE="$CONFIG_FILE"

[[ ! -f "\$CONFIG_FILE" ]] && { 
    echo "ERROR: Config not found at \$CONFIG_FILE"
    exit 1
}

source "\$CONFIG_FILE"

echo "🔐 Changing passwords from config file..."
echo "Config file: \$CONFIG_FILE"

# Change root password
echo "Changing root password..."
chroot "\$ARCH_ROOT" /usr/bin/bash -c "echo 'root:\$ROOT_PASS' | chpasswd"

# Change user password  
echo "Changing user password for \$USERNAME..."
chroot "\$ARCH_ROOT" /usr/bin/bash -c "echo '\$USERNAME:\$USER_PASS' | chpasswd"

echo "✅ Passwords updated successfully!"
echo "Use ./show-credentials.sh to view current passwords"
CHPWDEOF
    chmod +x "$TOOLS_DIR/change-passwords.sh"
    
    log "✓ Helper scripts created successfully"
    log "   Entry: $WORKSPACE_DIR/enter-arch*.sh"
    log "   Tools: $TOOLS_DIR/"
    log "   Debug: $WORKSPACE_DIR/debug-setup.sh"
    log "   Credentials: $WORKSPACE_DIR/show-credentials.sh"
    log "   Config file: $CONFIG_FILE"
}

main "$@"