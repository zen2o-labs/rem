#!/bin/bash
# /rem/scripts/04-setup-mounts.sh
set -euo pipefail

# Use environment variables from main script
ARCH_ROOT="${ARCH_ROOT:-${WORKSPACE_DIR:-$(pwd)}/arch-root}"

log() {
    echo "[$(date '+%H:%M:%S')] MOUNTS: $1"
}

main() {
    log "Setting up container-safe mounts for $ARCH_ROOT..."
    
    # Copy essential files
    cp /etc/resolv.conf "$ARCH_ROOT/etc/resolv.conf" 2>/dev/null || true
    cp /etc/passwd "$ARCH_ROOT/etc/passwd" 2>/dev/null || true
    cp /etc/group "$ARCH_ROOT/etc/group" 2>/dev/null || true
    
    # Try mount operations (container-safe)
    mount -t proc /proc "$ARCH_ROOT/proc" 2>/dev/null && log "✓ /proc mounted" || log "⚠ /proc mount failed"
    mount --make-rslave --rbind /sys "$ARCH_ROOT/sys" 2>/dev/null && log "✓ /sys mounted" || log "⚠ /sys mount failed"
    
    if mount --make-rslave --rbind /dev "$ARCH_ROOT/dev" 2>/dev/null; then
        log "✓ /dev mounted"
    else
        log "⚠ /dev mount failed, copying essential devices"
        mkdir -p "$ARCH_ROOT/dev"
        cp -a /dev/null /dev/zero /dev/random /dev/urandom "$ARCH_ROOT/dev/" 2>/dev/null || true
    fi
    
    mount --make-rslave --rbind /run "$ARCH_ROOT/run" 2>/dev/null && log "✓ /run mounted" || log "⚠ /run mount failed"
    
    log "✓ Mount setup completed"
}

main "$@"