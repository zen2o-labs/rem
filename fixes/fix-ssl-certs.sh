#!/bin/bash
# /rem/fixes/fix-ssl-certs.sh
set -euo pipefail

# Use environment variables from main script with proper fallbacks
ARCH_ROOT="${ARCH_ROOT:-${WORKSPACE_DIR:-$(pwd)}/arch-root}"
WORKSPACE_DIR="${WORKSPACE_DIR:-$(pwd)}"
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
    
    # Copy SSL certificates
    if [[ -f /etc/ssl/certs/ca-certificates.crt ]]; then
        mkdir -p "$ARCH_ROOT/etc/ssl/certs"
        cp /etc/ssl/certs/ca-certificates.crt "$ARCH_ROOT/etc/ssl/certs/"
        cp -r /etc/ssl/certs/* "$ARCH_ROOT/etc/ssl/certs/" 2>/dev/null || true
        log "✓ Copied main certificate bundle"
    fi
    
    # Set up Arch trust anchors
    mkdir -p "$ARCH_ROOT/etc/ca-certificates/trust-source/anchors"
    if [[ -f /etc/ssl/certs/ca-certificates.crt ]]; then
        cp /etc/ssl/certs/ca-certificates.crt "$ARCH_ROOT/etc/ca-certificates/trust-source/anchors/ubuntu-ca-certificates.crt"
    fi
    
    # Configure SSL environment variables
    cat > "$ARCH_ROOT/etc/profile.d/ssl-certs.sh" << 'EOF'
export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
export SSL_CERT_DIR=/etc/ssl/certs
export CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
export REQUESTS_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
EOF
    
    # Mark as completed
    touch "$MARKER_FILE"
    log "✓ SSL certificates configured successfully"
}

# Allow running standalone
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi