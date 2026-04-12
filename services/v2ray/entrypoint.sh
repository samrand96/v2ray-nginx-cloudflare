#!/bin/sh

# Xray Configuration Generator
# Supports: VLESS-WS, VLESS-XTLS-Reality

CONFIG_TEMPLATE="/etc/xray/config.template.json"
CONFIG_OUTPUT="/etc/xray/config.json"

echo "🚀 Generating Xray configuration..."

# Check if template exists
if [ ! -f "$CONFIG_TEMPLATE" ]; then
    echo "❌ Template file not found: $CONFIG_TEMPLATE"
    exit 1
fi

# Set default values if not provided
export V2RAY_UUID=${V2RAY_UUID:-"$(cat /proc/sys/kernel/random/uuid)"}
export VLESS_WS_PORT=${VLESS_WS_PORT:-1310}
export VLESS_WS_PATH=${VLESS_WS_PATH:-"/"}
export VLESS_REALITY_PORT=${VLESS_REALITY_PORT:-1313}
export REALITY_DEST=${REALITY_DEST:-"www.microsoft.com:443"}
export REALITY_SERVER_NAME=${REALITY_SERVER_NAME:-"www.microsoft.com"}
export REALITY_PRIVATE_KEY=${REALITY_PRIVATE_KEY:-""}
export REALITY_SHORT_ID=${REALITY_SHORT_ID:-"abcd1234"}

echo "📋 Configuration Summary:"
echo "   UUID: $V2RAY_UUID"
echo "   VLESS WebSocket: Port $VLESS_WS_PORT, Path: $VLESS_WS_PATH"
echo "   VLESS Reality: Port $VLESS_REALITY_PORT, Dest: $REALITY_DEST"

# Generate config by replacing environment variables
envsubst < "$CONFIG_TEMPLATE" > "$CONFIG_OUTPUT"

# Validate generated config
if xray run -test -c "$CONFIG_OUTPUT" > /dev/null 2>&1; then
    echo "✅ Configuration generated successfully!"
    echo "📁 Config saved to: $CONFIG_OUTPUT"
else
    echo "❌ Invalid configuration generated!"
    xray run -test -c "$CONFIG_OUTPUT"
    exit 1
fi

# Start Xray
echo "🌟 Starting Xray..."
exec xray run -c "$CONFIG_OUTPUT"