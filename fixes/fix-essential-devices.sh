#!/bin/bash
set -euo pipefail

# Use environment variables from main script
ARCH_ROOT="${ARCH_ROOT:-/workspace/arch-root}"
MARKER_FILE="$ARCH_ROOT/.essential_devices_fixed"

log() {
    echo "[$(date '+%H:%M:%S')] ESSENTIAL-DEVICES: $1"
}

main() {
    if [[ -f "$MARKER_FILE" ]]; then
        log "Essential devices already fixed, skipping..."
        return 0
    fi

    if [[ ! -d "$ARCH_ROOT" ]]; then
        log "ERROR: Arch root not found at $ARCH_ROOT"
        exit 1
    fi

    log "Fixing essential devices (/dev/null, /dev/zero, /dev/random, /dev/fd, etc.) for container compatibility..."
    
    # Create the comprehensive device fix script
    cat > "$ARCH_ROOT/tmp/fix-essential-devices.sh" << 'DEVICEFIX'
#!/bin/bash
set -euo pipefail

echo "=== Fixing Essential Devices for Container Environment ==="
echo "This will fix: /dev/null, /dev/zero, /dev/random, /dev/urandom, /dev/fd, stdio links"
echo "Plus: Shell environment compatibility (bash, zsh) and background services"

# Function to test if a device works
test_device() {
    local device="$1"
    local test_data="test-$$"
    
    if echo "$test_data" > "$device" 2>/dev/null; then
        echo "✅ $device is working"
        return 0
    else
        echo "❌ $device is not working"
        return 1
    fi
}

# Remove any broken devices
echo "Removing potentially broken devices..."
rm -f /dev/null /dev/zero /dev/random /dev/urandom 2>/dev/null || true

# Method 1: Try to create proper character device nodes
echo "Attempting to create proper device nodes..."
DEVICES_CREATED=false

if mknod /dev/null c 1 3 2>/dev/null && \
   mknod /dev/zero c 1 5 2>/dev/null && \
   mknod /dev/random c 1 8 2>/dev/null && \
   mknod /dev/urandom c 1 9 2>/dev/null; then
    
    # Set proper permissions
    chmod 666 /dev/null /dev/zero /dev/random /dev/urandom
    
    echo "✅ Created proper character device nodes"
    DEVICES_CREATED=true
else
    echo "⚠ Cannot create proper device nodes, using alternatives..."
    DEVICES_CREATED=false
fi

# Method 2: Create working alternatives if proper devices failed
if [[ "$DEVICES_CREATED" == "false" ]]; then
    echo "Creating functional device alternatives..."
    
    # Create /dev/null as a named pipe with consumer
    mkfifo /dev/null 2>/dev/null || {
        # Fallback: regular file with background truncation
        touch /dev/null
        chmod 666 /dev/null
        
        # Start background process to keep file empty
        nohup bash -c '
            while true; do
                > /dev/null 2>/dev/null || true
                sleep 1
            done
        ' >/tmp/null-keeper.log 2>&1 &
        
        echo "✅ Created /dev/null with background cleanup"
    }
    
    # Create /dev/zero
    if ! test_device /dev/zero; then
        mkfifo /dev/zero 2>/dev/null || touch /dev/zero
        chmod 666 /dev/zero
        
        # Background process to provide zeros
        nohup bash -c '
            while true; do
                printf "\0%.0s" {1..1024} > /dev/zero 2>/dev/null || true
                sleep 0.1
            done
        ' >/tmp/zero-provider.log 2>&1 &
    fi
    
    # Create /dev/random and /dev/urandom
    for device in random urandom; do
        if [[ ! -e "/dev/$device" ]]; then
            mkfifo "/dev/$device" 2>/dev/null || touch "/dev/$device"
            chmod 666 "/dev/$device"
            
            # Background process to provide random data
            nohup bash -c "
                while true; do
                    openssl rand -hex 1024 > /dev/$device 2>/dev/null || true
                    sleep 0.1
                done
            " >/tmp/$device-provider.log 2>&1 &
        fi
    done
    
    echo "✅ Created alternative device implementations"
fi

# Create file descriptor symlinks
echo "Setting up file descriptor symlinks..."
mkdir -p /dev/fd 2>/dev/null || true

# Try to create proper /dev/fd symlink
if ln -sf /proc/self/fd /dev/fd 2>/dev/null; then
    echo "✅ Created /dev/fd -> /proc/self/fd symlink"
else
    # Create manual fd entries
    mkdir -p /dev/fd
    for i in {0..10}; do
        touch "/dev/fd/$i" 2>/dev/null || true
    done
    echo "✅ Created manual /dev/fd entries"
fi

# Standard I/O symlinks
ln -sf /proc/self/fd/0 /dev/stdin 2>/dev/null || touch /dev/stdin
ln -sf /proc/self/fd/1 /dev/stdout 2>/dev/null || touch /dev/stdout  
ln -sf /proc/self/fd/2 /dev/stderr 2>/dev/null || touch /dev/stderr
chmod 666 /dev/std* 2>/dev/null || true

# Test all devices
echo "Testing device functionality..."
test_device /dev/null && NULL_WORKS=true || NULL_WORKS=false
test_device /dev/zero && ZERO_WORKS=true || ZERO_WORKS=false

# Special test for /dev/zero (should produce null bytes)
if head -c 10 /dev/zero 2>/dev/null | od -c | grep -q '\\0'; then
    echo "✅ /dev/zero produces null bytes correctly"
else
    echo "⚠ /dev/zero may not work properly"
fi

# Create shell environment fixes
echo "Creating shell environment fixes..."

# Fix for bash users
cat > /etc/profile.d/essential-devices-fix.sh << 'ENVFIX'
# Container essential devices compatibility fix
if [[ ! -w /dev/null ]] 2>/dev/null; then
    export NULL_REDIRECT="/tmp/null-$USER-$$"
    touch "$NULL_REDIRECT" 2>/dev/null || true
    chmod 666 "$NULL_REDIRECT" 2>/dev/null || true
fi
ENVFIX

# Fix for zsh users specifically
mkdir -p /etc/zsh 2>/dev/null || true
cat > /etc/zsh/zshenv << 'ZSHFIX'
# Zsh container compatibility for essential devices
if [[ ! -w /dev/null ]] 2>/dev/null; then
    # Skip problematic zsh initialization
    export DISABLE_AUTO_UPDATE="true"
    export ZSH_DISABLE_COMPFIX="true"
    
    # Provide alternative null device
    export ZSH_NULL_DEVICE="/tmp/zsh-null-$$"
    touch "$ZSH_NULL_DEVICE" 2>/dev/null || true
fi
ZSHFIX

# Create user-specific fixes
if [[ -d /home ]]; then
    for user_home in /home/*; do
        if [[ -d "$user_home" ]]; then
            user_name=$(basename "$user_home")
            
            # Add to user's bashrc
            cat >> "$user_home/.bashrc" << 'BASHFIX'

# Container essential devices fix
if [[ ! -w /dev/null ]] 2>/dev/null; then
    alias sudo='sudo 2>/tmp/sudo-stderr || sudo'
fi
BASHFIX
            
            # Create basic zshrc to avoid newuser prompts
            if [[ ! -f "$user_home/.zshrc" ]]; then
                cat > "$user_home/.zshrc" << 'ZRCFIX'
# Basic zsh config for container compatibility
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000
setopt appendhistory autocd beep extendedglob nomatch notify
bindkey -e

# Simple but functional prompt
PROMPT='%n@%m:%~$ '

# Essential aliases
alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'
ZRCFIX
                
                chown "$user_name:$user_name" "$user_home/.zshrc" 2>/dev/null || true
            fi
        fi
    done
fi

echo "=== Essential Devices Fix Summary ==="
echo "Null device working: $NULL_WORKS"
echo "Zero device working: $ZERO_WORKS"
echo "File descriptors: $(ls -la /dev/fd/ 2>/dev/null | wc -l) entries"
echo "Background processes: $(pgrep -f "null-keeper\|zero-provider\|random-provider" 2>/dev/null | wc -l) running"
echo "Shell fixes: bash, zsh environment configured"

if [[ "$NULL_WORKS" == "true" ]]; then
    echo "✅ Essential devices fix completed successfully"
else
    echo "⚠ Essential devices fix completed with warnings"
fi

echo "=== Essential Devices Fix Complete ==="
DEVICEFIX

    # Make the script executable and run it
    chmod +x "$ARCH_ROOT/tmp/fix-essential-devices.sh"
    
    log "Running essential devices fix inside chroot..."
    if chroot "$ARCH_ROOT" /tmp/fix-essential-devices.sh; then
        log "✓ Essential devices fix completed successfully"
    else
        log "⚠ Essential devices fix completed with warnings"
    fi
    
    # Clean up
    rm -f "$ARCH_ROOT/tmp/fix-essential-devices.sh"
    
    # Test the fix
    log "Testing essential devices functionality..."
    if chroot "$ARCH_ROOT" /bin/bash -c 'echo "test" > /dev/null 2>&1 && head -c 1 /dev/zero >/dev/null'; then
        log "✓ Essential devices test passed"
    else
        log "⚠ Some essential devices may not work properly"
    fi
    
    touch "$MARKER_FILE"
    log "✓ Essential devices fix applied and marked complete"
}

# Allow running standalone
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
