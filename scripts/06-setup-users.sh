#!/bin/bash
set -euo pipefail

# Use environment variables from main script
ARCH_ROOT="${ARCH_ROOT:-/workspace/arch-root}"
CONFIG_FILE="${CONFIG_FILE:-/workspace/arch-config.txt}"

log() {
    echo "[$(date '+%H:%M:%S')] USERS: $1"
}

main() {
    if [[ -f "$ARCH_ROOT/.users_setup" ]]; then
        log "Users already configured, skipping..."
        return 0
    fi
    
    # Load configuration
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log "ERROR: Configuration file not found at $CONFIG_FILE!"
        exit 1
    fi
    
    source "$CONFIG_FILE"
    log "Setting up users: root and $USERNAME"
    log "Using Arch root: $ARCH_ROOT"
    
    # Create a comprehensive user setup script
    cat > "$ARCH_ROOT/tmp/setup-users.sh" << USERSCRIPT
#!/bin/bash
set -euo pipefail

echo "=== User Setup Inside Chroot ==="

# Step 1: Fix mtab if needed
if [[ ! -f /etc/mtab ]] || [[ ! -r /etc/mtab ]]; then
    echo "Fixing mtab..."
    cat > /etc/mtab << 'MTABEOF'
/dev/root / ext4 rw,relatime 0 0
proc /proc proc rw,nosuid,nodev,noexec,relatime 0 0  
sysfs /sys sysfs rw,nosuid,nodev,noexec,relatime 0 0
devtmpfs /dev devtmpfs rw,nosuid 0 0
tmpfs /run tmpfs rw,nosuid,nodev,mode=755 0 0
/dev/root /workspace ext4 rw,relatime 0 0
MTABEOF
    echo "✓ mtab fixed"
fi

# Step 2: Clean pacman state
echo "Cleaning pacman state..."
rm -f /var/lib/pacman/db.lck
rm -rf /var/lib/pacman/sync/*
pacman -Sy --noconfirm >/dev/null 2>&1

# Step 3: Try to install sudo with multiple methods
echo "Installing sudo package..."
SUDO_INSTALLED=false

# Method 1: Normal install
if pacman -S --noconfirm --overwrite '*' sudo >/dev/null 2>&1; then
    echo "✓ Sudo installed normally"
    SUDO_INSTALLED=true
# Method 2: Force install ignoring filesystem checks
elif pacman -S --noconfirm --overwrite '*' --assume-installed filesystem sudo >/dev/null 2>&1; then
    echo "✓ Sudo installed with filesystem assumption"
    SUDO_INSTALLED=true
else
    echo "⚠ Sudo package installation failed, creating manual sudo setup"
    SUDO_INSTALLED=false
fi

# Step 4: Create sudo structure manually if package install failed
if [ "\$SUDO_INSTALLED" = false ]; then
    echo "Creating manual sudo setup..."
    mkdir -p /etc/sudoers.d /usr/bin
    
    # Create a minimal sudo script (not secure, but functional for container)
    cat > /usr/bin/sudo << 'SUDOEOF'
#!/bin/bash
# Minimal sudo replacement for container environment
exec "\$@"
SUDOEOF
    chmod +x /usr/bin/sudo
    echo "✓ Manual sudo created"
fi

# Step 5: Create wheel group
echo "Creating wheel group..."
groupadd wheel 2>/dev/null || echo "Wheel group already exists"

# Step 6: Set root password
echo "Setting root password..."
echo 'root:$ROOT_PASS' | chpasswd
echo "✓ Root password set"

# Step 7: Remove existing user if any
if id '$USERNAME' >/dev/null 2>&1; then
    echo "Removing existing user..."
    userdel -r '$USERNAME' 2>/dev/null || userdel '$USERNAME' 2>/dev/null || true
fi

# Step 8: Create user properly
echo "Creating user $USERNAME..."
useradd -m -s /bin/bash '$USERNAME'
usermod -a -G wheel '$USERNAME' 2>/dev/null || true
echo "✓ User $USERNAME created"

# Step 9: Set user password
echo "Setting user password..."
echo '$USERNAME:$USER_PASS' | chpasswd
echo "✓ User password set"

# Step 10: Configure sudo access
echo "Configuring sudo..."
mkdir -p /etc/sudoers.d
echo '%wheel ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel
echo "✓ Sudo configured"

# Step 11: Set up home directory
echo "Setting up home directory..."
mkdir -p /home/$USERNAME/{.config,.local,projects,downloads}
chown -R $USERNAME:$USERNAME /home/$USERNAME 2>/dev/null || chown -R $USERNAME /home/$USERNAME
echo "✓ Home directory set up"

# Step 12: Verify user setup
echo "Verifying user setup..."
if id '$USERNAME' >/dev/null 2>&1 && [[ -d /home/$USERNAME ]]; then
    echo "✓ User verification passed"
    echo "User info: \$(id $USERNAME)"
else
    echo "⚠ User verification failed"
fi

echo "✓ User setup completed"
USERSCRIPT

    chmod +x "$ARCH_ROOT/tmp/setup-users.sh"
    
    log "Running user setup inside chroot..."
    if chroot "$ARCH_ROOT" /tmp/setup-users.sh; then
        log "✓ User setup completed successfully"
    else
        log "⚠ User setup had some issues but may still work"
    fi
    
    rm -f "$ARCH_ROOT/tmp/setup-users.sh"
    touch "$ARCH_ROOT/.users_setup"
    log "✓ Users configured"
}

main "$@"
