#!/bin/bash

set -e

cd "$(dirname "$0")"

log_info() { echo "INFO: $1"; }
log_success() { echo "OK: $1"; }
log_error() { echo "ERROR: $1"; }

if [ -f ".env" ]; then
    set -a
    # shellcheck disable=SC1091
    . ./.env
    set +a
fi

DOMAIN=${DOMAIN:-}
HYSTERIA_PORT=${HYSTERIA_PORT:-443}
HYSTERIA_MASQUERADE_URL=${HYSTERIA_MASQUERADE_URL:-https://www.microsoft.com/}

if [ -z "$DOMAIN" ]; then
    log_error "DOMAIN is required in .env"
    exit 1
fi

if [ -z "$HYSTERIA_PASSWORD" ]; then
    log_error "HYSTERIA_PASSWORD is required in .env"
    exit 1
fi

if ! command -v envsubst >/dev/null 2>&1; then
    log_error "envsubst is required. Install gettext/gettext-base, then rerun."
    exit 1
fi

mkdir -p hysteria

export DOMAIN
export HYSTERIA_PORT
export HYSTERIA_PASSWORD
export HYSTERIA_MASQUERADE_URL

log_info "Generating hysteria/config.yaml"
envsubst < hysteria/config.template.yaml > hysteria/config.yaml
log_success "Generated hysteria/config.yaml"
