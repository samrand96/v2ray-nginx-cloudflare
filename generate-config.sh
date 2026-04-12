#!/bin/bash

# ============================================
# Xray Configuration Generator
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
    log_info "Please run easy-install.sh first or create .env manually"
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

# Determine which template to use based on what's configured
HAS_WS=false
HAS_REALITY=false

[ -n "$DOMAIN" ] && HAS_WS=true
[ -n "$REALITY_PRIVATE_KEY" ] && [ "$REALITY_PRIVATE_KEY" != "CHANGE-THIS-PRIVATE-KEY" ] && HAS_REALITY=true

if $HAS_WS && $HAS_REALITY; then
    TEMPLATE_FILE="v2ray/config/config.template.json"
    log_info "Mode: VLESS-WS + VLESS-Reality (dual)"
elif $HAS_REALITY; then
    TEMPLATE_FILE="v2ray/config/config.reality-only.template.json"
    log_info "Mode: VLESS-Reality only"
else
    TEMPLATE_FILE="v2ray/config/config.no-reality.template.json"
    log_info "Mode: VLESS-WS only"
fi

OUTPUT_FILE="v2ray/config/config.json"

log_info "Generating Xray configuration..."
log_info "  UUID: ${V2RAY_UUID:0:8}..."
$HAS_WS && log_info "  VLESS WS: Port 1310, Path /"
$HAS_REALITY && log_info "  VLESS Reality: Port 1313, Dest ${REALITY_DEST:-www.microsoft.com:443}"

# Ensure directories exist
mkdir -p v2ray/config

# Check for template
if [ ! -f "$TEMPLATE_FILE" ]; then
    log_error "Template file not found: $TEMPLATE_FILE"
    exit 1
fi

# Generate config using envsubst
if command -v envsubst &>/dev/null; then
    envsubst < "$TEMPLATE_FILE" > "$OUTPUT_FILE"
else
    # Fallback: use sed for all template variables
    log_info "Using sed for variable substitution..."
    cp "$TEMPLATE_FILE" "$OUTPUT_FILE"
    sed -i "s|\${V2RAY_UUID}|${V2RAY_UUID}|g" "$OUTPUT_FILE"
    sed -i "s|\${VLESS_WS_PORT}|${VLESS_WS_PORT:-1310}|g" "$OUTPUT_FILE"
    sed -i "s|\${VLESS_WS_PATH}|${VLESS_WS_PATH:-/}|g" "$OUTPUT_FILE"
    sed -i "s|\${VLESS_REALITY_PORT}|${VLESS_REALITY_PORT:-1313}|g" "$OUTPUT_FILE"
    sed -i "s|\${REALITY_DEST}|${REALITY_DEST:-www.microsoft.com:443}|g" "$OUTPUT_FILE"
    sed -i "s|\${REALITY_SERVER_NAME}|${REALITY_SERVER_NAME:-www.microsoft.com}|g" "$OUTPUT_FILE"
    sed -i "s|\${REALITY_PRIVATE_KEY}|${REALITY_PRIVATE_KEY}|g" "$OUTPUT_FILE"
    sed -i "s|\${REALITY_SHORT_ID}|${REALITY_SHORT_ID:-abcd1234}|g" "$OUTPUT_FILE"
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