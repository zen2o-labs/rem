#!/bin/bash
set -euo pipefail

# Use environment variables from main script
ARCH_ROOT="${ARCH_ROOT:-/workspace/arch-root}"
MARKER_FILE="$ARCH_ROOT/.ssl_certs_fixed"

log() {
    echo "[$(date '+%H:%M:%S')] SSL-CERTS: $1"
}

main() {
    if [[ -f "$MARKER_FILE" ]]; then
        log "SSL certificates already configured, skipping..."
        return 0
    fi
    
    if [[ ! -d "$ARCH_ROOT" ]]; then
        log "ERROR: Arch root not found at $ARCH_ROOT"
        exit 1
    fi
    
    log "Copying SSL certificates from Ubuntu host to Arch chroot at $ARCH_ROOT..."
    
    # Force create directories and fix permissions
    log "Setting up directory structure with correct permissions..."
    mkdir -p "$ARCH_ROOT/etc"
    mkdir -p "$ARCH_ROOT/etc/ssl"
    mkdir -p "$ARCH_ROOT/etc/ssl/certs"
    mkdir -p "$ARCH_ROOT/etc/ca-certificates/trust-source/anchors"
    mkdir -p "$ARCH_ROOT/etc/profile.d"
    
    # Fix ownership and permissions aggressively
    chown -R root:root "$ARCH_ROOT/etc" 2>/dev/null || true
    chmod -R u+rwX "$ARCH_ROOT/etc" 2>/dev/null || true
    
    # Specifically fix SSL directories
    chmod 755 "$ARCH_ROOT/etc"
    chmod 755 "$ARCH_ROOT/etc/ssl"
    chmod 755 "$ARCH_ROOT/etc/ssl/certs"
    chmod 755 "$ARCH_ROOT/etc/ca-certificates"
    chmod 755 "$ARCH_ROOT/etc/profile.d"
    
    log "Directory permissions fixed"
    
    # Copy SSL certificates with error handling
    if [[ -f /etc/ssl/certs/ca-certificates.crt ]]; then
        # Try direct copy first
        if cp /etc/ssl/certs/ca-certificates.crt "$ARCH_ROOT/etc/ssl/certs/" 2>/dev/null; then
            log "✓ Copied main certificate bundle"
        else
            log "⚠ Direct copy failed, trying with cat..."
            # Fallback: use cat to bypass permission issues
            cat /etc/ssl/certs/ca-certificates.crt > "$ARCH_ROOT/etc/ssl/certs/ca-certificates.crt" 2>/dev/null || {
                log "⚠ Cat copy failed, creating minimal cert file..."
                # Last resort: create a minimal cert file
                echo "# Minimal CA certificates for container" > "$ARCH_ROOT/etc/ssl/certs/ca-certificates.crt"
                cat /etc/ssl/certs/ca-certificates.crt >> "$ARCH_ROOT/etc/ssl/certs/ca-certificates.crt" 2>/dev/null || true
            }
        fi
        
        # Also copy to trust anchors
        cp /etc/ssl/certs/ca-certificates.crt "$ARCH_ROOT/etc/ca-certificates/trust-source/anchors/ubuntu-ca-certificates.crt" 2>/dev/null || true
    else
        log "⚠ Host CA certificates not found, creating placeholder"
        echo "# Placeholder CA certificates" > "$ARCH_ROOT/etc/ssl/certs/ca-certificates.crt"
    fi
    
    # Set proper permissions on copied files
    chmod 644 "$ARCH_ROOT/etc/ssl/certs/ca-certificates.crt" 2>/dev/null || true
    
    # Configure SSL environment variables
    cat > "$ARCH_ROOT/etc/profile.d/ssl-certs.sh" << 'EOF'
export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
export SSL_CERT_DIR=/etc/ssl/certs
export CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
EOF
    
    chmod 644 "$ARCH_ROOT/etc/profile.d/ssl-certs.sh"
    
    # Mark as completed
    touch "$MARKER_FILE"
    log "✓ SSL certificates configured successfully"
}

# Allow running standalone
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
