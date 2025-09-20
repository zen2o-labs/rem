#!/bin/bash
set -euo pipefail

# Use environment variables from main script
ARCH_ROOT="${ARCH_ROOT:-/workspace/arch-root}"
MARKER_FILE="$ARCH_ROOT/.dev_fd_fixed"

log() {
    echo "[$(date '+%H:%M:%S')] DEV-FD: $1"
}

main() {
    if [[ -f "$MARKER_FILE" ]]; then
        log "File descriptors already configured, skipping..."
        return 0
    fi

    if [[ ! -d "$ARCH_ROOT" ]]; then
        log "ERROR: Arch root not found at $ARCH_ROOT"
        exit 1
    fi

    log "Setting up file descriptor support for pacman-key..."
    
    chroot "$ARCH_ROOT" /bin/bash -c "
        # Try symlink approach first
        if ln -sf /proc/self/fd /dev/fd 2>/dev/null; then
            echo '✓ Created /dev/fd symlink'
        else
            # Fallback: create directory manually
            mkdir -p /dev/fd
            for i in {0..255}; do
                [[ \$i -lt 10 ]] && touch /dev/fd/\$i 2>/dev/null || true
            done
            echo '✓ Created /dev/fd directory manually'
        fi
        
        # Create standard I/O descriptors
        ln -sf /proc/self/fd/0 /dev/stdin 2>/dev/null || touch /dev/stdin
        ln -sf /proc/self/fd/1 /dev/stdout 2>/dev/null || touch /dev/stdout
        ln -sf /proc/self/fd/2 /dev/stderr 2>/dev/null || touch /dev/stderr
    " || log "File descriptor setup completed with warnings"
    
    touch "$MARKER_FILE"
    log "✓ File descriptor support configured"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
