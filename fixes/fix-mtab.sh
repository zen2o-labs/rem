#!/bin/bash
set -euo pipefail

# Use environment variables from main script
ARCH_ROOT="${ARCH_ROOT:-/workspace/arch-root}"
MARKER_FILE="$ARCH_ROOT/.mtab_fixed"

log() {
    echo "[$(date '+%H:%M:%S')] MTAB: $1"
}

main() {
    if [[ -f "$MARKER_FILE" ]]; then
        log "MTAB already configured, skipping..."
        return 0
    fi

    if [[ ! -d "$ARCH_ROOT" ]]; then
        log "ERROR: Arch root not found at $ARCH_ROOT"
        exit 1
    fi

    log "Fixing /etc/mtab for pacman filesystem detection..."
    
    chroot "$ARCH_ROOT" /usr/bin/bash << 'MTABFIX'
#!/bin/bash
set -euo pipefail

echo "=== MTAB Fix Inside Chroot ==="

# Remove any existing broken mtab
rm -f /etc/mtab

# Create a proper mtab file that pacman can read
cat > /etc/mtab << 'MTABEOF'
/dev/root / ext4 rw,relatime 0 0
proc /proc proc rw,nosuid,nodev,noexec,relatime 0 0
sysfs /sys sysfs rw,nosuid,nodev,noexec,relatime 0 0
devtmpfs /dev devtmpfs rw,nosuid,size=1024k,nr_inodes=1024 0 0
tmpfs /run tmpfs rw,nosuid,nodev,mode=755 0 0
/dev/root /workspace ext4 rw,relatime 0 0
MTABEOF

# Verify mtab is readable
if [[ -r /etc/mtab ]]; then
    echo "✓ /etc/mtab created and readable"
else
    echo "✗ /etc/mtab creation failed"
    exit 1
fi

# Clean pacman completely
echo "Cleaning pacman state..."
rm -f /var/lib/pacman/db.lck
rm -rf /var/lib/pacman/sync/*
mkdir -p /var/lib/pacman/sync

# Test pacman database sync
echo "Testing pacman sync..."
if pacman -Sy --noconfirm >/dev/null 2>&1; then
    echo "✓ Pacman sync working"
else
    echo "⚠ Pacman sync still having issues"
fi

echo "=== MTAB Fix Complete ==="
MTABFIX

    touch "$MARKER_FILE"
    log "✓ MTAB configured successfully"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
