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

    log "Downloading and extracting Arch Linux bootstrap (container-safe mode)..."

    # Clean up any existing arch-root
    if [[ -d "$ARCH_ROOT" ]]; then
        log "Removing existing arch-root..."
        chmod -R 777 "$ARCH_ROOT" 2>/dev/null || true
        rm -rf "$ARCH_ROOT" 2>/dev/null || {
            log "Could not remove existing arch-root, moving it aside..."
            mv "$ARCH_ROOT" "${ARCH_ROOT}-backup-$(date +%s)" || true
        }
    fi

    # Create target directory
    mkdir -p "$ARCH_ROOT"

    # Download and extract with container-safe options
    log "Downloading bootstrap..."
    wget -q -O- "$BOOTSTRAP_URL" | \
    tar --use-compress-program=unzstd \
        --strip-components=1 \
        --no-same-owner \
        --no-same-permissions \
        --no-overwrite-dir \
        --warning=no-unknown-keyword \
        --warning=no-timestamp \
        --exclude='**/ca-certificates/extracted/cadir/*.0' \
        --exclude='**/ca-certificates/extracted/cadir' \
        -xf - -C "$ARCH_ROOT" 2>/dev/null || {

        log "⚠ Standard extraction had issues, trying fallback method..."

        # Fallback: extract to temp directory first
        log "Using temporary extraction method..."
        TEMP_DIR="/tmp/arch-bootstrap-$$"
        mkdir -p "$TEMP_DIR"

        wget -q "$BOOTSTRAP_URL" -O "/tmp/arch-bootstrap.tar.zst"

        tar --use-compress-program=unzstd \
            --no-same-owner \
            --no-same-permissions \
            --warning=no-unknown-keyword \
            -xf "/tmp/arch-bootstrap.tar.zst" -C "$TEMP_DIR" || {
            log "ERROR: Failed to extract bootstrap"
            rm -rf "$TEMP_DIR" "/tmp/arch-bootstrap.tar.zst"
            exit 1
        }

        # Copy extracted files, skipping problematic ones
        log "Copying files (skipping problematic CA certificates)..."
        rsync -av \
            --exclude="etc/ca-certificates/extracted/cadir/*.0" \
            --exclude="etc/ca-certificates/extracted/cadir" \
            "$TEMP_DIR/root.x86_64/" "$ARCH_ROOT/" || {
            # If rsync not available, use cp
            cp -r "$TEMP_DIR/root.x86_64"/* "$ARCH_ROOT/" 2>/dev/null || true
        }

        # Clean up temp files
        rm -rf "$TEMP_DIR" "/tmp/arch-bootstrap.tar.zst"
    }

   log "Bootstrap extraction completed (SSL setup will be handled by fix scripts)"

    # Just create basic directory structure
    mkdir -p "$ARCH_ROOT"/{etc,usr,var,tmp,proc,sys,dev,run,bin}
    chmod 755 "$ARCH_ROOT/etc"
    chmod 1777 "$ARCH_ROOT/tmp"

    # Create bash symlinks
    # Create bash symlinks - but only if bash is a real executable
    if [[ -x "$ARCH_ROOT/usr/bin/bash" && ! -L "$ARCH_ROOT/usr/bin/bash" ]]; then
        ln -sf /usr/bin/bash "$ARCH_ROOT/bin/bash"
        ln -sf /usr/bin/bash "$ARCH_ROOT/bin/sh"
        log "✓ Created bash symlinks"
    else
        log "⚠ Real bash executable not found - may need manual extraction"
    fi

    touch "$ARCH_ROOT/.bootstrap_done"
    log "✓ Bootstrap completed (SSL certs will be handled by fix scripts)"
}

main "$@"
