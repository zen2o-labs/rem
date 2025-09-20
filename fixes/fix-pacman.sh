#!/bin/bash
set -euo pipefail

# Use environment variables from main script
ARCH_ROOT="${ARCH_ROOT:-/workspace/arch-root}"
MARKER_FILE="$ARCH_ROOT/.pacman_fixed"

log() {
    echo "[$(date '+%H:%M:%S')] PACMAN: $1"
}

main() {
    if [[ -f "$MARKER_FILE" ]]; then
        log "Pacman already configured, skipping..."
        return 0
    fi

    if [[ ! -d "$ARCH_ROOT" ]]; then
        log "ERROR: Arch root not found at $ARCH_ROOT"
        exit 1
    fi

    log "Configuring pacman for container environment..."
    
    chroot "$ARCH_ROOT" /bin/bash -c "
        # Backup original config
        [[ ! -f /etc/pacman.conf.original ]] && cp /etc/pacman.conf /etc/pacman.conf.original
        
        # Configure container-safe pacman
        cat > /etc/pacman.conf << 'PACEOF'
#
# /etc/pacman.conf - Container-safe configuration
#
[options]
HoldPkg     = pacman glibc
Architecture = auto
CheckSpace
SigLevel = Never
LocalFileSigLevel = Never
RemoteFileSigLevel = Never
ParallelDownloads = 5

[core]
Include = /etc/pacman.d/mirrorlist

[extra] 
Include = /etc/pacman.d/mirrorlist
PACEOF
        
        # Clean pacman state
        rm -f /var/lib/pacman/db.lck
        rm -rf /var/lib/pacman/sync/*
        
        # Test pacman functionality
        echo 'Testing pacman sync...'
        pacman -Sy --noconfirm >/dev/null 2>&1 && echo '✓ Pacman sync successful' || echo '⚠ Pacman sync had issues'
    "
    
    touch "$MARKER_FILE"
    log "✓ Pacman configured for container environment"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
