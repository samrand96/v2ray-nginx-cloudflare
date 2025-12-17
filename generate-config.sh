#!/bin/bash

# ============================================
# V2Ray Configuration Generator
# ============================================
# Generates v2ray/config/config.json from .env file
# Run this script after updating .env to apply changes
# ============================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${YELLOW}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Change to script directory
cd "$(dirname "$0")"

# Check if .env exists
if [ ! -f ".env" ]; then
    log_error ".env file not found!"
    log_info "Please run easy-install.sh first or copy .env.example to .env"
    exit 1
fi

# Load environment variables
log_info "Loading configuration from .env..."
set -a
source .env
set +a

# Validate UUID
if [ -z "$V2RAY_UUID" ] || [ "$V2RAY_UUID" = "CHANGE-THIS-UUID" ]; then
    log_error "V2RAY_UUID is not set or invalid!"
    log_info "Please set V2RAY_UUID in .env file"
    exit 1
fi

log_info "Generating V2Ray configuration..."
log_info "  UUID: ${V2RAY_UUID:0:8}..."
log_info "  VLESS WS: Port 1310, Path /"
log_info "  VLESS gRPC: Port 1311, Service grpc"
log_info "  VMess WS: Port 1312, Path /ws"

# Ensure directories exist
mkdir -p v2ray/config

# Check for template
TEMPLATE_FILE="v2ray/config/config.template.json"
OUTPUT_FILE="v2ray/config/config.json"

if [ ! -f "$TEMPLATE_FILE" ]; then
    log_error "Template file not found: $TEMPLATE_FILE"
    exit 1
fi

# Generate config using envsubst
if command -v envsubst &>/dev/null; then
    envsubst < "$TEMPLATE_FILE" > "$OUTPUT_FILE"
else
    # Fallback: use sed
    log_info "Using sed for variable substitution..."
    cp "$TEMPLATE_FILE" "$OUTPUT_FILE"
    sed -i "s|\${V2RAY_UUID}|${V2RAY_UUID}|g" "$OUTPUT_FILE"
fi

# Validate JSON (if jq is available)
if command -v jq &>/dev/null; then
    if jq empty "$OUTPUT_FILE" 2>/dev/null; then
        log_success "Configuration generated and validated: $OUTPUT_FILE"
    else
        log_error "Generated configuration is invalid JSON!"
        exit 1
    fi
else
    log_success "Configuration generated: $OUTPUT_FILE"
    log_info "Install jq for JSON validation: apt install jq"
fi

echo ""
log_info "To apply changes, restart the v2ray container:"
echo "   docker compose -f docker-compose.modular.yml restart v2ray"
echo ""
