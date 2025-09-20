#!/bin/bash
# /container-setup.sh
set -eo pipefail

# Configuration variables with defaults
WORKSPACE="${WORKSPACE:-/workspace}"
REPO_NAME="${REPO_NAME:-rem}"  
ARCH_ROOT="${WORKSPACE}/arch-root"
REPO_DIR="${WORKSPACE}/${REPO_NAME}"

# User credential variables - compatible with unified config
ARCH_USERNAME="${ARCH_USERNAME:-developer}"
ARCH_USER_PASSWORD="${ARCH_USER_PASSWORD:-}"
ARCH_ROOT_PASSWORD="${ARCH_ROOT_PASSWORD:-}"

echo "🚀 RunPod Arch Linux Setup - Starting..."
echo "📁 Workspace: $WORKSPACE"
echo "📦 Repository: zen2o-labs/rem.git"
echo "👤 User: $ARCH_USERNAME"

# Clone repository  
echo "📥 Cloning repository..."
rm -rf "$REPO_DIR"
git clone "https://github.com/zen2o-labs/rem.git" "$REPO_DIR"

# Make scripts executable
echo "🔧 Making scripts executable..."

if [[ -d "$REPO_DIR" ]]; then
    # Make all shell scripts executable in key directories
    chmod +x "$REPO_DIR"/*.sh 2>/dev/null || true
    chmod +x "$REPO_DIR/scripts"/*.sh 2>/dev/null || true  
    chmod +x "$REPO_DIR/fixes"/*.sh 2>/dev/null || true
    
    echo "✅ Made executable: main scripts, scripts/, and fixes/"
else
    echo "❌ Repository directory not found: $REPO_DIR"
    exit 1
fi

# Export variables for the Arch setup scripts to match unified config approach
export WORKSPACE_DIR="$WORKSPACE"
export SCRIPT_DIR="$REPO_DIR"  
export ARCH_ROOT
export CONFIG_FILE="$WORKSPACE/arch-config.txt"

# Run Arch setup if not already done
if [[ ! -f "$ARCH_ROOT/.setup_complete" ]]; then
    echo "🐧 Setting up Arch Linux environment..."
    
    # Pre-configure credentials if provided - compatible with unified config
    if [[ -n "$ARCH_USER_PASSWORD" || -n "$ARCH_ROOT_PASSWORD" ]]; then
        echo "🔐 Pre-configuring with provided credentials..."
        
        # Generate passwords if not provided
        USER_PASS="${ARCH_USER_PASSWORD:-$(openssl rand -base64 12 | tr -d '=+/' | cut -c1-12 2>/dev/null || echo "dev$(date +%s | tail -c 6)")}"
        ROOT_PASS="${ARCH_ROOT_PASSWORD:-$(openssl rand -base64 12 | tr -d '=+/' | cut -c1-12 2>/dev/null || echo "root$(date +%s | tail -c 6)")}"
        
        # Create unified config file that matches our updated start.sh format
        mkdir -p "$WORKSPACE"
        cat > "$CONFIG_FILE" << CONFIGEOF
# Arch Linux Unified Configuration - Generated $(date)
# This file contains both setup parameters and user credentials

# ===== DIRECTORY CONFIGURATION =====
# Repository location (where scripts are located)
SCRIPT_DIR="$REPO_DIR"

# Workspace location (where arch-root and tools will be created) 
WORKSPACE_DIR="$WORKSPACE"

# Directory where the Arch Linux root filesystem will be created
ARCH_ROOT="$ARCH_ROOT"

# Directory containing fix scripts
FIXES_DIR="$REPO_DIR/fixes"

# Directory containing setup scripts
SCRIPTS_DIR="$REPO_DIR/scripts"

# Directory for tools (created in workspace, not in repo)
TOOLS_DIR="$WORKSPACE/tools"

# ===== SETUP SCRIPT CONFIGURATION =====
# Order of setup scripts to execute (space-separated list)
# You can modify this list to skip or reorder scripts
SETUP_SCRIPTS="01-install-deps.sh 02-generate-config.sh 03-setup-bootstrap.sh 04-setup-mounts.sh 05-run-fixes.sh 06-setup-users.sh 07-create-helpers.sh"

# ===== USER CREDENTIALS =====
# Default user account settings
USERNAME="$ARCH_USERNAME"
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
CONFIGEOF
        chmod 600 "$CONFIG_FILE"
        echo "✅ Unified configuration with custom credentials created"
    fi
    
    # Run the unified setup script
    cd "$REPO_DIR"
    ./start.sh
    
    # Mark setup as complete
    touch "$ARCH_ROOT/.setup_complete"
    echo "✅ Arch Linux setup completed"
else
    echo "✅ Arch Linux environment already exists"
fi

# Load the final unified configuration
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
    DISPLAY_USERNAME="$USERNAME"
    DISPLAY_WORKSPACE="$WORKSPACE_DIR"
    DISPLAY_ARCH_ROOT="$ARCH_ROOT"
else
    DISPLAY_USERNAME="$ARCH_USERNAME"
    DISPLAY_WORKSPACE="$WORKSPACE"
    DISPLAY_ARCH_ROOT="$ARCH_ROOT"
fi

# Create interactive shell selector
cat > ~/.shell_selector.sh << 'EOF'
#!/bin/bash

# Simple shell selector
WORKSPACE="/workspace"
CONFIG_FILE="$WORKSPACE/arch-config.txt"

# Skip if not interactive or already selected
if [[ ! -t 0 ]] || [[ -n "${SHELL_SELECTED:-}" ]]; then
    return 0
fi

# Load username from config
USERNAME="developer"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE" 2>/dev/null || true
fi

echo ""
echo "=== Arch Linux Environment ==="
echo ""
echo "Choose your shell:"
echo "1) Arch Linux ($USERNAME user)"
echo "2) Ubuntu (root user)"
echo "3) Show status"
echo ""

read -p "Choice [1-3]: " -n 1 choice
echo ""

case $choice in
    1)
        export SHELL_SELECTED=arch
        echo "Starting Arch Linux..."
        if [[ -f "$WORKSPACE/enter-arch-user.sh" ]]; then
            exec "$WORKSPACE/enter-arch-user.sh"
        else
            echo "Arch not ready. Run: $WORKSPACE/rem/start.sh"
        fi
        ;;
    2)
        export SHELL_SELECTED=ubuntu
        export PS1="[Ubuntu] \w # "
        echo "Ubuntu shell ready"
        ;;
    3)
        if [[ -f "$WORKSPACE/verify-setup.sh" ]]; then
            "$WORKSPACE/verify-setup.sh"
        else
            echo "Status script not available"
        fi
        ;;
    *)
        export SHELL_SELECTED=ubuntu
        echo "Invalid choice, using Ubuntu shell"
        ;;
esac
EOF
chmod +x ~/.shell_selector.sh

# Configure SSH to show interactive menu
cat >> ~/.bashrc << 'BASHRCEOF'
# Interactive shell selection for SSH sessions - Handle unbound variables safely
if [[ $- == *i* && -z "${SHELL_SELECTED:-}" ]]; then
    source ~/.shell_selector.sh
fi
BASHRCEOF

# Create direct access scripts
cat > "$WORKSPACE/arch-direct.sh" << ARCHDIRECTEOF
#!/bin/bash
echo "🐧 Direct access to Arch Linux..."
export SHELL_SELECTED=arch

# Check if entry script exists
if [[ -f "$WORKSPACE/enter-arch-user.sh" ]]; then
    exec "$WORKSPACE/enter-arch-user.sh"
else
    echo "❌ Entry script not found at $WORKSPACE/enter-arch-user.sh"
    echo "📋 Run: $WORKSPACE/rem/start.sh to set up"
    exit 1
fi
ARCHDIRECTEOF
chmod +x "$WORKSPACE/arch-direct.sh"

cat > "$WORKSPACE/ubuntu-direct.sh" << UBUNTUDIRECTEOF
#!/bin/bash
echo "🐳 Direct access to Ubuntu shell..."
export SHELL_SELECTED=ubuntu
export PS1="\\[\\e[1;34m\\][Ubuntu]\\[\\e[0m\\] \\w # "
exec /bin/bash --norc
UBUNTUDIRECTEOF
chmod +x "$WORKSPACE/ubuntu-direct.sh"

# Create verification script compatible with unified config
cat > "$WORKSPACE/verify-setup.sh" << VERIFYEOF
#!/bin/bash
echo "🔍 System Status Check"
echo "===================="
echo "📁 Workspace: $DISPLAY_WORKSPACE"
echo "📦 Repository: $REPO_DIR"
echo "👤 User: $DISPLAY_USERNAME"
echo "📄 Config: $CONFIG_FILE"
echo ""

if [[ -f "$DISPLAY_ARCH_ROOT/.setup_complete" ]]; then
    echo "✅ Arch Linux: Ready"
    
    # Show credentials using unified config approach
    if [[ -f "$WORKSPACE/show-credentials.sh" ]]; then
        echo ""
        echo "🔐 Access Information:"
        "$WORKSPACE/show-credentials.sh"
    fi
    
    # Check if user can enter Arch (with timeout to avoid hanging)
    if timeout 5 bash -c "source '$CONFIG_FILE' 2>/dev/null && [[ -d '\\$ARCH_ROOT' ]]" 2>/dev/null; then
        echo ""
        echo "✅ Arch Access: Paths verified"
    else
        echo ""
        echo "❌ Arch Access: Configuration issues"
    fi
    
    # Show helper scripts
    helper_count=\\$(ls "$WORKSPACE"/{enter-arch,show-credentials}*.sh 2>/dev/null | wc -l)
    echo "✅ Helper Scripts: \\$helper_count available"
    
    # Show tools
    if [[ -d "$WORKSPACE/tools" ]]; then
        tool_count=\\$(ls "$WORKSPACE/tools"/*.sh 2>/dev/null | wc -l)
        echo "✅ Tools: \\$tool_count available"
    fi
    
else
    echo "❌ Arch Linux: Not configured"
    echo "📋 Run: $REPO_DIR/start.sh to set up"
fi

echo ""
echo "🔗 Direct Access:"
echo "  $WORKSPACE/arch-direct.sh   - Go straight to Arch"
echo "  $WORKSPACE/ubuntu-direct.sh - Go straight to Ubuntu"
VERIFYEOF
chmod +x "$WORKSPACE/verify-setup.sh"

echo ""
echo "✅ Interactive setup complete!"
echo ""
echo "📁 Workspace: $DISPLAY_WORKSPACE"
echo "📦 Repository: $REPO_DIR"
echo "👤 Username: $DISPLAY_USERNAME"
echo "📄 Config: $CONFIG_FILE"

if [[ -n "$ARCH_USER_PASSWORD" ]]; then
    echo "🔐 Custom credentials: Used"
else
    echo "🔐 Generated credentials: Check $CONFIG_FILE"
fi

echo ""
echo "🔗 Access methods:"
echo "  SSH: Interactive choice menu"
echo "  Direct Arch: $WORKSPACE/arch-direct.sh"
echo "  Direct Ubuntu: $WORKSPACE/ubuntu-direct.sh"
echo "  Verification: $WORKSPACE/verify-setup.sh"
echo "  Dashboard: $WORKSPACE/tools/dashboard.sh"