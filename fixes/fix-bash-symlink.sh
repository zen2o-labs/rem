#!/bin/bash
set -euo pipefail

ARCH_ROOT="${ARCH_ROOT:-/workspace/arch-root}"
MARKER_FILE="$ARCH_ROOT/.bash_symlink_fixed"

log() {
    echo "[$(date '+%H:%M:%S')] BASH-SYMLINK: $1"
}

main() {
    if [[ -f "$MARKER_FILE" ]]; then
        log "Bash symlinks already configured, skipping..."
        return 0
    fi
    
    log "Verifying and fixing bash symlinks..."
    
    # Check if we have a real bash executable
    if [[ -x "$ARCH_ROOT/usr/bin/bash" && ! -L "$ARCH_ROOT/usr/bin/bash" ]]; then
        log "✓ Real bash executable found"
        
        # Remove any broken symlinks
        rm -f "$ARCH_ROOT/bin/bash" "$ARCH_ROOT/bin/sh" 2>/dev/null || true
        
        # Create proper symlinks
        mkdir -p "$ARCH_ROOT/bin"
        ln -sf /usr/bin/bash "$ARCH_ROOT/bin/bash"
        ln -sf /usr/bin/bash "$ARCH_ROOT/bin/sh"
        log "✓ Created proper bash symlinks"
        
    else
        log "❌ No real bash executable found - fixing..."
        
        # Remove broken symlinks
        rm -f "$ARCH_ROOT/usr/bin/bash" "$ARCH_ROOT/bin/bash" "$ARCH_ROOT/bin/sh" 2>/dev/null || true
        
        # Extract real bash from bootstrap
        TEMP_DIR="/tmp/bash-fix-$$"
        mkdir -p "$TEMP_DIR"
        
        wget -q -O /tmp/arch-bootstrap.tar.zst https://archive.archlinux.org/iso/2025.09.01/archlinux-bootstrap-x86_64.tar.zst
        
        tar --use-compress-program=unzstd \
            --no-same-owner \
            -xf /tmp/arch-bootstrap.tar.zst \
            root.x86_64/usr/bin/bash \
            -C "$TEMP_DIR" 2>/dev/null
        
        if [[ -x "$TEMP_DIR/root.x86_64/usr/bin/bash" ]]; then
            cp "$TEMP_DIR/root.x86_64/usr/bin/bash" "$ARCH_ROOT/usr/bin/bash"
            chmod 755 "$ARCH_ROOT/usr/bin/bash"
            
            # Now create symlinks
            mkdir -p "$ARCH_ROOT/bin"
            ln -sf /usr/bin/bash "$ARCH_ROOT/bin/bash"
            ln -sf /usr/bin/bash "$ARCH_ROOT/bin/sh"
            log "✓ Extracted and fixed bash"
        else
            log "❌ Could not extract bash - using host bash"
            cp /usr/bin/bash "$ARCH_ROOT/usr/bin/bash"
            chmod 755 "$ARCH_ROOT/usr/bin/bash"
            
            mkdir -p "$ARCH_ROOT/bin"
            ln -sf /usr/bin/bash "$ARCH_ROOT/bin/bash"
            ln -sf /usr/bin/bash "$ARCH_ROOT/bin/sh"
        fi
        
        rm -rf "$TEMP_DIR" /tmp/arch-bootstrap.tar.zst
    fi
    
    # Test the fix
    if chroot "$ARCH_ROOT" /usr/bin/bash -c "echo 'Bash test OK'" >/dev/null 2>&1; then
        log "✅ Bash test successful"
    else
        log "❌ Bash still not working"
        return 1
    fi
    
    touch "$MARKER_FILE"
    log "✓ Bash symlinks verified and fixed"
}

main "$@"
