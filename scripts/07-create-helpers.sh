#!/bin/bash
set -euo pipefail

# Use environment variables from main script
TOOLS_DIR="${TOOLS_DIR:-$WORKSPACE_DIR/tools}"

log() {
    echo "[$(date '+%H:%M:%S')] HELPERS: $1"
}

main() {
    log "Creating helper scripts in $TOOLS_DIR..."
    log "Workspace directory: $WORKSPACE_DIR"
    log "Arch root directory: $ARCH_ROOT"

    # Load config to get username
    source "$CONFIG_FILE"

    # Create tools directory in workspace (not in repo)
    mkdir -p "$TOOLS_DIR"

    # Main entry scripts in workspace root (NOT in arch-root)
    cat > "$WORKSPACE_DIR/enter-arch.sh" << EOF
#!/bin/bash
set -euo pipefail

# Auto-detect workspace and load configuration
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="\$SCRIPT_DIR/arch-config.txt"

if [[ ! -f "\$CONFIG_FILE" ]]; then
    echo "ERROR: Configuration file not found at \$CONFIG_FILE"
    echo "Run the setup first: ./arch-chroot-runpod/start.sh"
    exit 1
fi

# Load configuration
source "\$CONFIG_FILE"

if [[ ! -d "\$ARCH_ROOT" ]]; then
    echo "ERROR: Arch root directory not found at \$ARCH_ROOT"
    echo "Run the setup first: ./arch-chroot-runpod/start.sh"
    exit 1
fi

exec chroot "\$ARCH_ROOT" /bin/bash -l
EOF
    chmod +x "$WORKSPACE_DIR/enter-arch.sh"

    cat > "$WORKSPACE_DIR/enter-arch-user.sh" << EOF
    #!/bin/bash
    set -euo pipefail

    # Auto-detect workspace and load configuration
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    CONFIG_FILE="$SCRIPT_DIR/arch-config.txt"

    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo "ERROR: Configuration file not found at $CONFIG_FILE"
        echo "Run the setup first: ./arch-chroot-runpod/start.sh"
        exit 1
    fi

    # Load configuration
    source "$CONFIG_FILE"

    if [[ ! -d "$ARCH_ROOT" ]]; then
        echo "ERROR: Arch root directory not found at $ARCH_ROOT"
        echo "Run the setup first: ./arch-chroot-runpod/start.sh"
        exit 1
    fi

    if [[ ! -d "$ARCH_ROOT/home/$USERNAME" ]]; then
        echo "ERROR: User home directory not found at $ARCH_ROOT/home/$USERNAME"
        echo "User setup may have failed. Check the setup logs."
        exit 1
    fi

    echo "Entering Arch Linux as user: $USERNAME"

    # Method 1: Direct approach (most reliable in containers)
    exec chroot "$ARCH_ROOT" /bin/bash -c "
        export HOME=/home/$USERNAME
        export USER=$USERNAME
        export LOGNAME=$USERNAME
        export SHELL=/bin/bash
        export PS1='[\u@\h \W]\\$ '
        export PATH='/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
        cd /home/$USERNAME
        exec su -l $USERNAME
    "

EOF
    chmod +x "$WORKSPACE_DIR/enter-arch-user.sh"

    # Package management tools
    cat > "$TOOLS_DIR/install-packages.sh" << EOF
#!/bin/bash
set -euo pipefail

# Auto-detect workspace and load configuration
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="\$SCRIPT_DIR/arch-config.txt"

if [[ ! -f "\$CONFIG_FILE" ]]; then
    echo "ERROR: Configuration file not found at \$CONFIG_FILE"
    exit 1
fi

# Load configuration
source "\$CONFIG_FILE"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

if [[ \$# -eq 0 ]]; then
    echo -e "\${YELLOW}Usage:\${NC} \$0 <package1> [package2] [...]"
    echo -e "\${YELLOW}Example:\${NC} \$0 git vim python nodejs"
    echo ""
    echo -e "\${BLUE}Popular packages:\${NC}"
    echo "  Development: git vim neovim python nodejs npm"
    echo "  System: htop tree wget curl unzip zip"
    echo "  Network: openssh git-lfs"
    exit 1
fi

echo -e "\${BLUE}📦 Installing packages:\${NC} \$*"
echo ""

chroot "\$ARCH_ROOT" /bin/bash << PKGEOF
    set -euo pipefail

    echo "🔄 Updating package database..."
    rm -f /var/lib/pacman/db.lck
    pacman -Sy --noconfirm >/dev/null 2>&1

    echo "📥 Installing packages..."
    if pacman -S --noconfirm --overwrite '*' \$*; then
        echo -e "\\n✅ Successfully installed: \$*"
        echo ""
        echo "📋 Installed packages summary:"
        for pkg in \$*; do
            if pacman -Q \\\$pkg >/dev/null 2>&1; then
                version=\\\$(pacman -Q \\\$pkg | awk '{print \\\$2}')
                echo "   ✓ \\\$pkg (\\\$version)"
            fi
        done
    else
        echo -e "\\n❌ Some packages failed to install"
        exit 1
    fi
PKGEOF

echo ""
echo -e "\${GREEN}Installation completed!\${NC}"
EOF
    chmod +x "$TOOLS_DIR/install-packages.sh"

    # Credentials display
    cat > "$WORKSPACE_DIR/show-credentials.sh" << EOF
#!/bin/bash

# Auto-detect workspace and load configuration
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="\$SCRIPT_DIR/arch-config.txt"

echo "=== Arch Linux Chroot Credentials ==="
echo ""

if [[ ! -f "\$CONFIG_FILE" ]]; then
    echo "❌ Configuration file not found at \$CONFIG_FILE"
    echo ""
    echo "Please run the setup first:"
    if [[ -f "\$SCRIPT_DIR/arch-chroot-runpod/start.sh" ]]; then
        echo "  \$SCRIPT_DIR/arch-chroot-runpod/start.sh"
    else
        echo "  Clone the repository and run start.sh"
    fi
    exit 1
fi

# Load configuration
source "\$CONFIG_FILE"

echo "📁 Locations:"
echo "  Repository: \$SCRIPT_DIR/arch-chroot-runpod"
echo "  Workspace: \$WORKSPACE_DIR"
echo "  Arch root: \$ARCH_ROOT"
echo "  Config file: \$CONFIG_FILE"
echo ""

if [[ -d "\$ARCH_ROOT" ]]; then
    echo "✅ Arch environment: Ready"
else
    echo "❌ Arch environment: Not found"
    echo "   Run setup: \$SCRIPT_DIR/arch-chroot-runpod/start.sh"
    exit 1
fi

echo ""
echo "🔐 Root Access:"
echo "  Username: root"
echo "  Password: \$ROOT_PASS"
echo "  Command:  \$WORKSPACE_DIR/enter-arch.sh"
echo ""
echo "👤 User Access:"
echo "  Username: \$USERNAME"
echo "  Password: \$USER_PASS"
echo "  Command:  \$WORKSPACE_DIR/enter-arch-user.sh"

if [[ -d "\$ARCH_ROOT/home/\$USERNAME" ]]; then
    echo "  Status: ✅ User ready"
else
    echo "  Status: ❌ User not found (setup may have failed)"
fi

echo "  Sudo: Yes (passwordless)"
echo ""
echo "🛠️ Tools:"
echo "  \$WORKSPACE_DIR/tools/install-packages.sh <pkg>  - Install packages"
echo "  \$WORKSPACE_DIR/tools/quick-setup.sh             - Install essentials"
if [[ -f "\$WORKSPACE_DIR/tools/dashboard.sh" ]]; then
    echo "  \$WORKSPACE_DIR/tools/dashboard.sh               - System dashboard"
fi
EOF
    chmod +x "$WORKSPACE_DIR/show-credentials.sh"

    # Quick setup
    cat > "$TOOLS_DIR/quick-setup.sh" << EOF
#!/bin/bash
set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "\${BLUE}🚀 Quick Arch Linux Setup\${NC}"
echo ""

echo -e "\${YELLOW}Installing essential packages...\${NC}"
"\$( dirname "\${BASH_SOURCE[0]}" )/install-packages.sh" base-devel git wget curl nano vim sudo python htop tree fastfetch neofetch

echo ""
echo -e "\${GREEN}✅ Quick setup completed!\${NC}"
echo ""
echo -e "\${BLUE}What's installed:\${NC}"
echo "  • Build tools (base-devel)"
echo "  • Git version control"
echo "  • Text editors (nano, vim)"
echo "  • System utilities (htop, tree)"
echo "  • System information (fastfetch, neofetch)"
echo ""
echo -e "\${YELLOW}Next steps:\${NC}"
echo "  1. $TOOLS_DIR/dev-setup.sh     - Full development environment"
echo "  2. $WORKSPACE_DIR/enter-arch-user.sh     - Enter as user"
echo "  3. $TOOLS_DIR/dashboard.sh     - View system dashboard"
EOF
    chmod +x "$TOOLS_DIR/quick-setup.sh"

    # Password changer
    cat > "$TOOLS_DIR/change-passwords.sh" << EOF
#!/bin/bash
set -euo pipefail

# Auto-detect workspace and load configuration
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="\$SCRIPT_DIR/arch-config.txt"

if [[ ! -f "\$CONFIG_FILE" ]]; then
    echo "ERROR: Configuration file not found at \$CONFIG_FILE"
    exit 1
fi

source "\$CONFIG_FILE"

echo "Updating passwords..."
chroot "\$ARCH_ROOT" /bin/bash -c "
    echo 'root:\$ROOT_PASS' | chpasswd
    echo '\$USERNAME:\$USER_PASS' | chpasswd
"
echo "✓ Passwords updated"
EOF
    chmod +x "$TOOLS_DIR/change-passwords.sh"

    # Create debug script
    cat > "$WORKSPACE_DIR/debug-setup.sh" << EOF
#!/bin/bash

echo "=== Arch Chroot Debug Information ==="
echo ""

SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
echo "Current directory: \$SCRIPT_DIR"
echo ""

echo "📁 File structure:"
ls -la "\$SCRIPT_DIR"
echo ""

if [[ -f "\$SCRIPT_DIR/arch-config.txt" ]]; then
    echo "✅ Config file found"
    source "\$SCRIPT_DIR/arch-config.txt"
    echo "   Arch root should be: \$ARCH_ROOT"
    echo "   Username: \$USERNAME"
    echo ""

    if [[ -d "\$ARCH_ROOT" ]]; then
        echo "✅ Arch root directory exists"
        echo "   Contents:"
        ls -la "\$ARCH_ROOT" | head -10
        echo ""

        if [[ -d "\$ARCH_ROOT/home/\$USERNAME" ]]; then
            echo "✅ User home directory exists"
        else
            echo "❌ User home directory missing"
            echo "   Expected: \$ARCH_ROOT/home/\$USERNAME"
        fi
    else
        echo "❌ Arch root directory missing"
        echo "   Expected: \$ARCH_ROOT"
    fi
else
    echo "❌ Config file missing: \$SCRIPT_DIR/arch-config.txt"
    echo ""
    echo "Available setup scripts:"
    find "\$SCRIPT_DIR" -name "start.sh" -type f 2>/dev/null || echo "   No start.sh found"
fi

echo ""
echo "🔧 Recommended actions:"
if [[ ! -f "\$SCRIPT_DIR/arch-config.txt" ]]; then
    echo "   1. Run setup: ./arch-chroot-runpod/start.sh"
elif [[ ! -d "\$ARCH_ROOT" ]]; then
    echo "   1. Run setup again: ./arch-chroot-runpod/start.sh"
elif [[ ! -d "\$ARCH_ROOT/home/\$USERNAME" ]]; then
    echo "   1. Re-run user setup: ./arch-chroot-runpod/scripts/06-setup-users.sh"
else
    echo "   Everything looks good! Try: ./enter-arch-user.sh"
fi
EOF
    chmod +x "$WORKSPACE_DIR/debug-setup.sh"

    log "✓ Helper scripts created successfully"
    log "   Entry scripts: $WORKSPACE_DIR/enter-arch*.sh"
    log "   Tools: $TOOLS_DIR/"
    log "   Credentials: $WORKSPACE_DIR/show-credentials.sh"
    log "   Debug: $WORKSPACE_DIR/debug-setup.sh"
}

main "$@"
