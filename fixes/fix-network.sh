#!/bin/bash
# /rem/fixes/fix-network.sh
set -euo pipefail

# Use environment variables from main script with proper fallbacks
ARCH_ROOT="${ARCH_ROOT:-${WORKSPACE_DIR:-$(pwd)}/arch-root}"
WORKSPACE_DIR="${WORKSPACE_DIR:-$(pwd)}"
MARKER_FILE="$ARCH_ROOT/.network_fixed"

log() {
    echo "[$(date '+%H:%M:%S')] NETWORK: $1"
}

main() {
    if [[ -f "$MARKER_FILE" ]]; then
        log "Network already configured, skipping..."
        return 0
    fi
    
    if [[ ! -d "$ARCH_ROOT" ]]; then
        log "ERROR: Arch root not found at $ARCH_ROOT"
        exit 1
    fi
    
    log "Configuring network access for Arch chroot..."
    
    # Update DNS configuration
    cat > "$ARCH_ROOT/etc/resolv.conf" << 'EOF'
nameserver 8.8.8.8
nameserver 1.1.1.1
nameserver 1.0.0.1
EOF
    
    # Set up reliable mirrors (HTTP for initial setup)
    cat > "$ARCH_ROOT/etc/pacman.d/mirrorlist" << 'EOF'
# Reliable mirrors for container environment
Server = http://mirrors.kernel.org/archlinux/$repo/os/$arch
Server = http://mirror.rackspace.com/archlinux/$repo/os/$arch
Server = http://mirrors.mit.edu/archlinux/$repo/os/$arch
EOF
    
    touch "$MARKER_FILE"
    log "✓ Network configuration completed"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi