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
    
    # Create necessary directories first
    mkdir -p "$ARCH_ROOT/etc/ssl/certs"
    mkdir -p "$ARCH_ROOT/etc/ca-certificates/trust-source/anchors"
    mkdir -p "$ARCH_ROOT/etc/profile.d"  # This was missing!
    
    # Set proper permissions
    chmod 755 "$ARCH_ROOT/etc"
    chmod 755 "$ARCH_ROOT/etc/ssl"
    chmod 755 "$ARCH_ROOT/etc/ssl/certs"
    
    # Copy SSL certificates
    if [[ -f /etc/ssl/certs/ca-certificates.crt ]]; then
        cp /etc/ssl/certs/ca-certificates.crt "$ARCH_ROOT/etc/ssl/certs/"
        cp -r /etc/ssl/certs/* "$ARCH_ROOT/etc/ssl/certs/" 2>/dev/null || true
        log "✓ Copied main certificate bundle"
    fi
    
    # Set up Arch trust anchors
    if [[ -f /etc/ssl/certs/ca-certificates.crt ]]; then
        cp /etc/ssl/certs/ca-certificates.crt "$ARCH_ROOT/etc/ca-certificates/trust-source/anchors/ubuntu-ca-certificates.crt"
    fi
    
    # Configure SSL environment variables (now the directory exists)
    cat > "$ARCH_ROOT/etc/profile.d/ssl-certs.sh" << 'EOF'
export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
export SSL_CERT_DIR=/etc/ssl/certs
export CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
EOF
    
    # Make the profile script executable
    chmod 644 "$ARCH_ROOT/etc/profile.d/ssl-certs.sh"
    
    # Mark as completed
    touch "$MARKER_FILE"
    log "✓ SSL certificates configured successfully"
}

# Allow running standalone
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
