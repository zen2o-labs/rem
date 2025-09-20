#!/bin/bash
set -euo pipefail

log() {
    echo "[$(date '+%H:%M:%S')] DEPS: $1"
}

main() {
    log "Installing system dependencies..."
    
    apt update -qq
    apt install -y -qq arch-install-scripts wget zstd openssl curl
    
    log "✓ Dependencies installed"
}

main "$@"
