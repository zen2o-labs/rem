#!/bin/bash
# /container-setup.sh
set -euo pipefail

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
find "$REPO_DIR" -maxdepth 3 -type f -name "*.sh" -not -path "*/arch-root/*" -exec chmod +x {} \\;

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
cat > ~/.shell_selector.sh << SELECTOREOF
#!/bin/bash
# Configuration from unified config
CONFIG_FILE="$CONFIG_FILE"
WORKSPACE="$DISPLAY_WORKSPACE"
ARCH_ROOT="$DISPLAY_ARCH_ROOT"
USERNAME="$DISPLAY_USERNAME"

# Skip if already selected or non-interactive
[[ -n "\\$SHELL_SELECTED" || ! -t 0 ]] && return 0

echo ""
echo "🐧 Welcome to RunPod with Arch Linux Chroot!"
echo ""

if [[ -f "\\$ARCH_ROOT/.setup_complete" ]]; then
    echo "✅ Arch Linux environment is ready"
    
    # Show credentials info
    if [[ -f "\\$WORKSPACE/show-credentials.sh" ]]; then
        echo "📋 Quick info:"
        "\\$WORKSPACE/show-credentials.sh" | grep -E "(Username|Password)" | head -4
        echo ""
    fi
    
    echo "🔍 Choose your environment:"
    echo "  [1] 🐧 Enter Arch Linux (\\$USERNAME user)"
    echo "  [2] 🐳 Stay in Ubuntu shell (root)"
    echo "  [3] 📊 Show system dashboard first"
    echo ""
    
    while true; do
        read -p "Enter choice [1-3]: " -n 1 choice
        echo ""
        
        case \\$choice in
            1)
                echo "🚀 Entering Arch Linux as \\$USERNAME user..."
                sleep 1
                export SHELL_SELECTED=arch
                if [[ -f "\\$WORKSPACE/enter-arch-user.sh" ]]; then
                    exec "\\$WORKSPACE/enter-arch-user.sh"
                else
                    echo "❌ Entry script not found. Run: \\$WORKSPACE/rem/start.sh"
                    export SHELL_SELECTED=ubuntu
                fi
                ;;
            2)
                echo "🐳 Staying in Ubuntu shell"
                export SHELL_SELECTED=ubuntu
                export PS1="\\[\\e[1;34m\\][Ubuntu]\\[\\e[0m\\] \\w # "
                break
                ;;
            3)
                echo "📊 System Dashboard:"
                if [[ -f "\\$WORKSPACE/tools/dashboard.sh" ]]; then
                    "\\$WORKSPACE/tools/dashboard.sh"
                elif [[ -f "\\$WORKSPACE/verify-setup.sh" ]]; then
                    "\\$WORKSPACE/verify-setup.sh"
                else
                    echo "Dashboard not available. Setup may be incomplete."
                fi
                echo ""
                echo "Press any key to continue..."
                read -n 1
                # Loop back to choice menu
                ;;
            *)
                echo "❌ Invalid choice. Please enter 1, 2, or 3."
                ;;
        esac
    done
else
    echo "❌ Arch Linux environment not ready"
    echo "📋 Run: \\$WORKSPACE/rem/start.sh"
    echo ""
    echo "🐳 Starting Ubuntu shell..."
    export PS1="\\[\\e[1;31m\\][Ubuntu-Setup-Needed]\\[\\e[0m\\] \\w # "
fi
SELECTOREOF
chmod +x ~/.shell_selector.sh

# Configure SSH to show interactive menu
cat >> ~/.bashrc << 'BASHRCEOF'
# Interactive shell selection for SSH sessions
if [[ $- == *i* && -z "$SHELL_SELECTED" ]]; then
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