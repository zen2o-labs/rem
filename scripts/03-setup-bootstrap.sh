#!/bin/bash
set -euo pipefail

# Use environment variables from main script
ARCH_ROOT="${ARCH_ROOT:-/workspace/arch-root}"
BOOTSTRAP_URL="https://archive.archlinux.org/iso/2025.09.01/archlinux-bootstrap-x86_64.tar.zst"

log() {
    echo "[$(date '+%H:%M:%S')] BOOTSTRAP: $1"
}

main() {
    if [[ -f "$ARCH_ROOT/.bootstrap_done" ]]; then
        log "Bootstrap already exists, skipping..."
        return 0
    fi
    
    log "Downloading Arch Linux bootstrap to $ARCH_ROOT..."
    mkdir -p /tmp/arch-setup
    cd /tmp/arch-setup
    
    wget -q "$BOOTSTRAP_URL" -O arch-bootstrap.tar.zst || {
        log "ERROR: Failed to download bootstrap"
        exit 1
    }
    
    log "Extracting bootstrap..."
    tar --use-compress-program=unzstd -xf arch-bootstrap.tar.zst --numeric-owner || {
        log "ERROR: Failed to extract bootstrap"
        exit 1
    }
    
    mv root.x86_64 "$ARCH_ROOT"
    rm -rf /tmp/arch-setup
    
    touch "$ARCH_ROOT/.bootstrap_done"
    log "✓ Bootstrap setup completed at $ARCH_ROOT"
}

main "$@"
