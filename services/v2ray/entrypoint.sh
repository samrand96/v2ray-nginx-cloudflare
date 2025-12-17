#!/bin/sh

# V2Ray Multi-Protocol Configuration Generator
# This script generates the V2Ray config.json from template based on environment variables

CONFIG_TEMPLATE="/etc/v2ray/config.template.json"
CONFIG_OUTPUT="/etc/v2ray/config.json"

echo "🚀 Generating V2Ray configuration..."

# Check if template exists
if [ ! -f "$CONFIG_TEMPLATE" ]; then
    echo "❌ Template file not found: $CONFIG_TEMPLATE"
    exit 1
fi

# Set default values if not provided
export V2RAY_UUID=${V2RAY_UUID:-"$(cat /proc/sys/kernel/random/uuid)"}
export VLESS_WS_PORT=${VLESS_WS_PORT:-1310}
export VLESS_WS_PATH=${VLESS_WS_PATH:-"/"}
export VLESS_GRPC_PORT=${VLESS_GRPC_PORT:-1311}
export VLESS_GRPC_SERVICE=${VLESS_GRPC_SERVICE:-"grpc"}
export VMESS_WS_PORT=${VMESS_WS_PORT:-1312}
export VMESS_WS_PATH=${VMESS_WS_PATH:-"/ws"}

echo "📋 Configuration Summary:"
echo "   UUID: $V2RAY_UUID"
echo "   VLESS WebSocket: Port $VLESS_WS_PORT, Path: $VLESS_WS_PATH"
echo "   VLESS gRPC: Port $VLESS_GRPC_PORT, Service: $VLESS_GRPC_SERVICE"
echo "   VMess WebSocket: Port $VMESS_WS_PORT, Path: $VMESS_WS_PATH"

# Generate config by replacing environment variables
envsubst < "$CONFIG_TEMPLATE" > "$CONFIG_OUTPUT"

# Validate generated config
if v2ray -test -config="$CONFIG_OUTPUT" > /dev/null 2>&1; then
    echo "✅ Configuration generated successfully!"
    echo "📁 Config saved to: $CONFIG_OUTPUT"
else
    echo "❌ Invalid configuration generated!"
    v2ray -test -config="$CONFIG_OUTPUT"
    exit 1
fi

# Start V2Ray
echo "🌟 Starting V2Ray with multi-protocol support..."
exec v2ray -config="$CONFIG_OUTPUT"