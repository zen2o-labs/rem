#!/bin/bash
# /rem/fixes/fix-sudo-permissions.sh

set -euo pipefail

ARCH_ROOT="${ARCH_ROOT:-${WORKSPACE_DIR:-$(pwd)}/arch-root}"
MARKER_FILE="$ARCH_ROOT/.sudo_fixed"

log() {
    echo "[$(date '+%H:%M:%S')] SUDO-FIX: $1"
}

main() {
    if [[ -f "$MARKER_FILE" ]]; then
        log "Sudo permissions already fixed, skipping..."
        return 0
    fi
    
    if [[ ! -d "$ARCH_ROOT" ]]; then
        log "ERROR: Arch root not found at $ARCH_ROOT"
        exit 1
    fi
    
    log "Fixing sudo permissions for container environment..."
    
    # Fix sudo configuration files
    if [[ -f "$ARCH_ROOT/etc/sudo.conf" ]]; then
        chown root:root "$ARCH_ROOT/etc/sudo.conf"
        chmod 644 "$ARCH_ROOT/etc/sudo.conf"
        log "✓ Fixed /etc/sudo.conf ownership"
    fi
    
    if [[ -f "$ARCH_ROOT/etc/sudoers" ]]; then
        chown root:root "$ARCH_ROOT/etc/sudoers"
        chmod 440 "$ARCH_ROOT/etc/sudoers"
        log "✓ Fixed /etc/sudoers ownership"
    fi
    
    # Fix sudoers.d directory and contents
    if [[ -d "$ARCH_ROOT/etc/sudoers.d" ]]; then
        chown root:root "$ARCH_ROOT/etc/sudoers.d"
        chmod 750 "$ARCH_ROOT/etc/sudoers.d"
        
        # Fix all files in sudoers.d
        for file in "$ARCH_ROOT/etc/sudoers.d"/*; do
            if [[ -f "$file" ]]; then
                chown root:root "$file"
                chmod 440 "$file"
            fi
        done 2>/dev/null || true
        log "✓ Fixed /etc/sudoers.d ownership"
    fi
    
    # Fix sudo binary - this is critical!
    if [[ -f "$ARCH_ROOT/usr/bin/sudo" ]]; then
        chown root:root "$ARCH_ROOT/usr/bin/sudo"
        chmod 4755 "$ARCH_ROOT/usr/bin/sudo"  # setuid bit is essential
        log "✓ Fixed /usr/bin/sudo ownership and setuid bit"
    else
        log "⚠ /usr/bin/sudo not found - may need to install sudo package"
    fi
    
    # Fix other sudo-related binaries
    for binary in sudoedit sudoreplay visudo; do
        if [[ -f "$ARCH_ROOT/usr/bin/$binary" ]]; then
            chown root:root "$ARCH_ROOT/usr/bin/$binary"
            # sudoedit needs setuid, others don't
            if [[ "$binary" == "sudoedit" ]]; then
                chmod 4755 "$ARCH_ROOT/usr/bin/$binary"
            else
                chmod 755 "$ARCH_ROOT/usr/bin/$binary"
            fi
            log "  ✓ Fixed $binary"
        fi
    done
    
    # Fix PAM configuration for sudo (if it exists)
    if [[ -f "$ARCH_ROOT/etc/pam.d/sudo" ]]; then
        chown root:root "$ARCH_ROOT/etc/pam.d/sudo"
        chmod 644 "$ARCH_ROOT/etc/pam.d/sudo"
        log "✓ Fixed PAM sudo configuration"
    fi
    
    # Verify the fix worked
    if chroot "$ARCH_ROOT" sudo -V >/dev/null 2>&1; then
        log "✅ Sudo is now working correctly"
    else
        log "⚠ Sudo may still have issues - check permissions manually"
    fi
    
    touch "$MARKER_FILE"
    log "✓ Sudo permissions fix completed"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
