#!/bin/bash
set -euo pipefail

ARCH_ROOT="${ARCH_ROOT:-/workspace/arch-root}"
BOOTSTRAP_URL="https://archive.archlinux.org/iso/2025.09.01/archlinux-bootstrap-x86_64.tar.zst"

log() {
    echo "[$(date '+%H:%M:%S')] BOOTSTRAP-SAFE: $1"
}

main() {
    if [[ -f "$ARCH_ROOT/.bootstrap_done" ]]; then
        log "Bootstrap already exists, skipping..."
        return 0
    fi
    
    log "Setting up Arch Linux bootstrap (container-safe method)..."
    
    # Create target directory
    mkdir -p "$ARCH_ROOT"
    
    # Download and extract directly to target
    log "Downloading and extracting bootstrap..."
    
    wget -q -O- "$BOOTSTRAP_URL" | \
    tar --use-compress-program=unzstd \
        --strip-components=1 \
        --no-same-owner \
        --no-same-permissions \
        --warning=no-unknown-keyword \
        -xf - -C "$ARCH_ROOT" || {
        log "ERROR: Failed to download/extract bootstrap"
        exit 1
    }
    
    log "Bootstrap extracted successfully"
    
    # Fix ownership and permissions
    log "Applying container-safe permissions..."
    
    # Set basic ownership
    chown -R 0:0 "$ARCH_ROOT" 2>/dev/null || true
    
    # Fix directory permissions
    find "$ARCH_ROOT" -type d -exec chmod 755 {} + 2>/dev/null || true
    
    # Fix executable permissions
    find "$ARCH_ROOT/usr/bin" -type f -exec chmod 755 {} + 2>/dev/null || true
    find "$ARCH_ROOT/usr/sbin" -type f -exec chmod 755 {} + 2>/dev/null || true
    
    # Special directories
    chmod 1777 "$ARCH_ROOT/tmp" 2>/dev/null || true
    chmod 700 "$ARCH_ROOT/root" 2>/dev/null || true
    
    # Create essential mount points
    mkdir -p "$ARCH_ROOT"/{proc,sys,dev,run}
    
    touch "$ARCH_ROOT/.bootstrap_done"
    log "✓ Container-safe bootstrap completed"
}

main "$@"
