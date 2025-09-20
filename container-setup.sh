#!/bin/bash
set -euo pipefail

# Configuration variables with defaults
WORKSPACE="${WORKSPACE:-/workspace}"
REPO_NAME="${REPO_NAME:-rem}"  
GITHUB_USER="${GITHUB_USER:-YOUR_USERNAME}"
ARCH_ROOT="${WORKSPACE}/arch-root"
REPO_DIR="${WORKSPACE}/${REPO_NAME}"

# User credential variables
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
find "$REPO_DIR" -maxdepth 3 -type f -name "*.sh" -not -path "*/arch-root/*" -exec chmod +x {} \;

# Export variables for the Arch setup scripts
export WORKSPACE ARCH_ROOT REPO_DIR
export ARCH_USERNAME ARCH_USER_PASSWORD ARCH_ROOT_PASSWORD

# Run Arch setup if not already done
if [[ ! -f "$ARCH_ROOT/.setup_complete" ]]; then
    echo "🐧 Setting up Arch Linux environment..."
    
    # Pre-create config if credentials provided
    if [[ -n "$ARCH_USER_PASSWORD" || -n "$ARCH_ROOT_PASSWORD" ]]; then
        echo "🔐 Using provided credentials..."
        
        # Generate passwords if not provided
        USER_PASS="${ARCH_USER_PASSWORD:-$(openssl rand -base64 12 | tr -d '=+/' | cut -c1-12)}"
        ROOT_PASS="${ARCH_ROOT_PASSWORD:-$(openssl rand -base64 12 | tr -d '=+/' | cut -c1-12)}"
        
        # Create config file before setup
        mkdir -p "$WORKSPACE"
        cat > "$WORKSPACE/arch-config.txt" << CONFIGEOF
# Arch Linux Configuration - Generated $(date)
# Repository: $REPO_DIR
# Workspace: $WORKSPACE

USERNAME="$ARCH_USERNAME"
USER_PASS="$USER_PASS"
ROOT_PASS="$ROOT_PASS"

# Directory locations (auto-detected)
WORKSPACE_DIR="$WORKSPACE"
ARCH_ROOT="$ARCH_ROOT"
SCRIPT_DIR="$REPO_DIR"

# Edit these values and run $WORKSPACE/tools/change-passwords.sh to apply changes
CONFIGEOF
        chmod 600 "$WORKSPACE/arch-config.txt"
        echo "✅ Custom credentials configured"
    fi
    
    # Run the setup
    "$REPO_DIR/start.sh"
else
    echo "✅ Arch Linux environment already exists"
fi

# Load the final configuration
if [[ -f "$WORKSPACE/arch-config.txt" ]]; then
    source "$WORKSPACE/arch-config.txt"
    DISPLAY_USERNAME="$USERNAME"
else
    DISPLAY_USERNAME="$ARCH_USERNAME"
fi

# Create interactive shell selector
cat > ~/.shell_selector.sh << SELECTOREOF
#!/bin/bash

# Configuration
WORKSPACE="$WORKSPACE"
ARCH_ROOT="$ARCH_ROOT"
USERNAME="$DISPLAY_USERNAME"

# Skip if already selected or non-interactive
[[ -n "\$SHELL_SELECTED" || ! -t 0 ]] && return 0

echo ""
echo "🐧 Welcome to RunPod with Arch Linux Chroot!"
echo ""

if [[ -f "\$ARCH_ROOT/.setup_complete" ]]; then
    echo "✅ Arch Linux environment is ready"
    
    # Show credentials info
    if [[ -f "\$WORKSPACE/show-credentials.sh" ]]; then
        echo "📋 Quick info:"
        "\$WORKSPACE/show-credentials.sh" | grep -E "(Username|Password)" | head -4
        echo ""
    fi
    
    echo "🔍 Choose your environment:"
    echo "  [1] 🐧 Enter Arch Linux (\$USERNAME user with zsh)"
    echo "  [2] 🐳 Stay in Ubuntu shell (root)"
    echo "  [3] 📊 Show system dashboard first"
    echo ""
    
    while true; do
        read -p "Enter choice [1-3]: " -n 1 choice
        echo ""
        
        case \$choice in
            1)
                echo "🚀 Entering Arch Linux as \$USERNAME user..."
                sleep 1
                export SHELL_SELECTED=arch
                exec "\$WORKSPACE/enter-arch-user.sh"
                ;;
            2)
                echo "🐳 Staying in Ubuntu shell"
                export SHELL_SELECTED=ubuntu
                export PS1="\\[\\e[1;34m\\][Ubuntu]\\[\\e[0m\\] \\w # "
                break
                ;;
            3)
                echo "📊 System Dashboard:"
                "\$WORKSPACE/tools/dashboard.sh" 2>/dev/null || "\$WORKSPACE/verify-setup.sh"
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
    echo "📋 Run: \$WORKSPACE/$REPO_NAME/start.sh"
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
exec "$WORKSPACE/enter-arch-user.sh"
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

# Create verification script with credentials
cat > "$WORKSPACE/verify-setup.sh" << VERIFYEOF
#!/bin/bash
echo "🔍 System Status Check"
echo "===================="
echo "📁 Workspace: $WORKSPACE"
echo "📦 Repository: $REPO_DIR"
echo "👤 User: $DISPLAY_USERNAME"
echo ""

if [[ -f "$ARCH_ROOT/.setup_complete" ]]; then
    echo "✅ Arch Linux: Ready"
    
    # Show credentials
    if [[ -f "$WORKSPACE/show-credentials.sh" ]]; then
        echo ""
        echo "🔐 Credentials:"
        "$WORKSPACE/show-credentials.sh" | grep -A 10 "Root Access:"
    fi
    
    # Check if user can enter Arch
    if timeout 5 "$WORKSPACE/enter-arch.sh" -c "echo 'Arch test OK'" >/dev/null 2>&1; then
        echo "✅ Arch Access: Working"
    else
        echo "❌ Arch Access: Issues"
    fi
    
    # Show helper scripts
    helper_count=\$(ls "$WORKSPACE"/{enter-arch,show-credentials}*.sh 2>/dev/null | wc -l)
    echo "✅ Helper Scripts: \$helper_count available"
    
    # Show tools
    if [[ -d "$WORKSPACE/tools" ]]; then
        tool_count=\$(ls "$WORKSPACE/tools"/*.sh 2>/dev/null | wc -l)
        echo "✅ Tools: \$tool_count available"
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
echo "📁 Workspace: $WORKSPACE"
echo "📦 Repository: $REPO_DIR"
echo "👤 Username: $DISPLAY_USERNAME"
if [[ -n "$ARCH_USER_PASSWORD" ]]; then
    echo "🔐 Custom credentials: Used"
else
    echo "🔐 Generated credentials: Check $WORKSPACE/arch-config.txt"
fi
echo ""
echo "🔗 Access methods:"
echo "  SSH: Interactive choice menu"
echo "  Direct Arch: $WORKSPACE/arch-direct.sh"
echo "  Direct Ubuntu: $WORKSPACE/ubuntu-direct.sh"
echo "  Verification: $WORKSPACE/verify-setup.sh"
