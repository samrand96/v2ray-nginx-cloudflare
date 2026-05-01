#!/bin/bash

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}INFO:${NC} $1"; }
log_success() { echo -e "${GREEN}OK:${NC} $1"; }
log_warning() { echo -e "${YELLOW}WARN:${NC} $1"; }
log_error() { echo -e "${RED}ERROR:${NC} $1"; }

cd "$(dirname "$0")"

generate_password() {
    local password=""
    password=$(tr -dc 'A-Za-z0-9' </dev/urandom 2>/dev/null | head -c 24 || true)
    if [ -z "$password" ]; then
        password="$(date +%s)$RANDOM$RANDOM"
    fi
    echo "$password"
}

urlencode() {
    local raw="$1"
    if command -v jq >/dev/null 2>&1; then
        jq -nr --arg v "$raw" '$v|@uri'
    else
        printf '%s' "$raw"
    fi
}

get_server_ip() {
    timeout 10 curl -4s --connect-timeout 5 ifconfig.me 2>/dev/null || \
    timeout 10 curl -4s --connect-timeout 5 icanhazip.com 2>/dev/null || \
    echo "YOUR-SERVER-IP"
}

escape_sed_replacement() {
    printf '%s' "$1" | sed -e 's/[\/&]/\\&/g'
}

set_env_var() {
    local key="$1"
    local value="$2"

    if [ ! -f ".env" ]; then
        {
            echo "# ============================================"
            echo "# Xray + Hysteria Proxy Configuration"
            echo "# ============================================"
        } > .env
    fi

    if grep -q "^${key}=" .env; then
        local escaped_value
        escaped_value=$(escape_sed_replacement "$value")
        sed -i.bak "s|^${key}=.*|${key}=${escaped_value}|" .env
        rm -f .env.bak
    else
        printf '%s=%s\n' "$key" "$value" >> .env
    fi
}

DOCKER_COMPOSE=""
if command -v docker-compose >/dev/null 2>&1; then
    DOCKER_COMPOSE="docker-compose"
elif docker compose version >/dev/null 2>&1; then
    DOCKER_COMPOSE="docker compose"
else
    log_error "Docker Compose not found"
    exit 1
fi

if [ -f ".env" ]; then
    set -a
    # shellcheck disable=SC1091
    . ./.env
    set +a
fi

echo "Hysteria 2 standalone installer"
echo "================================"
echo "This reuses the certificate created by nginx/acme in ./certs."
echo ""

read -p "Enter certificate domain [${DOMAIN:-}]: " INPUT_DOMAIN
DOMAIN=${INPUT_DOMAIN:-${DOMAIN:-}}
while [ -z "$DOMAIN" ]; do
    log_error "Domain cannot be empty"
    read -p "Enter certificate domain: " DOMAIN
done

read -p "Enter Hysteria UDP port [${HYSTERIA_PORT:-443}]: " INPUT_HYSTERIA_PORT
HYSTERIA_PORT=${INPUT_HYSTERIA_PORT:-${HYSTERIA_PORT:-443}}
if [[ ! "$HYSTERIA_PORT" =~ ^[0-9]+$ ]] || [ "$HYSTERIA_PORT" -lt 1 ] || [ "$HYSTERIA_PORT" -gt 65535 ]; then
    log_warning "Invalid Hysteria port, using 443"
    HYSTERIA_PORT=443
fi

DEFAULT_PASSWORD=${HYSTERIA_PASSWORD:-$(generate_password)}
read -p "Enter Hysteria password [keep/generate]: " INPUT_HYSTERIA_PASSWORD
HYSTERIA_PASSWORD=${INPUT_HYSTERIA_PASSWORD:-$DEFAULT_PASSWORD}

read -p "Enter Hysteria masquerade URL [${HYSTERIA_MASQUERADE_URL:-https://www.microsoft.com/}]: " INPUT_MASQ
HYSTERIA_MASQUERADE_URL=${INPUT_MASQ:-${HYSTERIA_MASQUERADE_URL:-https://www.microsoft.com/}}

HYSTERIA_VERSION=${HYSTERIA_VERSION:-latest}
HYSTERIA_CONTAINER_NAME=${HYSTERIA_CONTAINER_NAME:-hysteria}
RESTART_POLICY=${RESTART_POLICY:-always}
DOCKER_LOG_DRIVER=${DOCKER_LOG_DRIVER:-json-file}
DOCKER_LOG_MAX_SIZE=${DOCKER_LOG_MAX_SIZE:-2m}
DOCKER_LOG_MAX_FILE=${DOCKER_LOG_MAX_FILE:-2}
HYSTERIA_MEMORY_LIMIT=${HYSTERIA_MEMORY_LIMIT:-128m}

if [ ! -f "./certs/${DOMAIN}.crt" ] || [ ! -f "./certs/${DOMAIN}.key" ]; then
    log_error "Missing shared certificate for ${DOMAIN}"
    echo ""
    echo "Expected:"
    echo "  ./certs/${DOMAIN}.crt"
    echo "  ./certs/${DOMAIN}.key"
    echo ""
    echo "Run the main installer first and choose WS, Both, or All so nginx/acme obtains the cert:"
    echo "  sudo bash install.sh"
    exit 1
fi

set_env_var "DOMAIN" "$DOMAIN"
set_env_var "HYSTERIA_VERSION" "$HYSTERIA_VERSION"
set_env_var "HYSTERIA_CONTAINER_NAME" "$HYSTERIA_CONTAINER_NAME"
set_env_var "HYSTERIA_PORT" "$HYSTERIA_PORT"
set_env_var "HYSTERIA_PASSWORD" "$HYSTERIA_PASSWORD"
set_env_var "HYSTERIA_MASQUERADE_URL" "$HYSTERIA_MASQUERADE_URL"
set_env_var "RESTART_POLICY" "$RESTART_POLICY"
set_env_var "DOCKER_LOG_DRIVER" "$DOCKER_LOG_DRIVER"
set_env_var "DOCKER_LOG_MAX_SIZE" "$DOCKER_LOG_MAX_SIZE"
set_env_var "DOCKER_LOG_MAX_FILE" "$DOCKER_LOG_MAX_FILE"
set_env_var "HYSTERIA_MEMORY_LIMIT" "$HYSTERIA_MEMORY_LIMIT"

mkdir -p logs/hysteria

bash ./generate-hysteria-config.sh

log_info "Starting Hysteria container"
$DOCKER_COMPOSE -f docker-compose.hysteria.yml up -d

SERVER_IP=$(get_server_ip)
echo ""
echo "Hysteria 2 link:"
echo "hysteria2://$(urlencode "$HYSTERIA_PASSWORD")@${SERVER_IP}:${HYSTERIA_PORT}/?sni=${DOMAIN}#Hysteria2"
echo ""
echo "Use server IP as address, keep SNI set to ${DOMAIN}, and open UDP/${HYSTERIA_PORT} on your firewall."
echo "Do not put Hysteria behind Cloudflare proxy."
