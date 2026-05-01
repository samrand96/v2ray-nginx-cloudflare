#!/bin/bash

set -e

cd "$(dirname "$0")"

COMPOSE_FILE="${1:-docker-compose.modular.yml}"

if command -v docker-compose >/dev/null 2>&1; then
    DOCKER_COMPOSE="docker-compose"
elif docker compose version >/dev/null 2>&1; then
    DOCKER_COMPOSE="docker compose"
else
    echo "ERROR: Docker Compose not found"
    exit 1
fi

if [ -f ".env" ]; then
    set -a
    # shellcheck disable=SC1091
    . ./.env
    set +a
fi

echo "Tiny VPS mode"
echo "============="
echo "Compose file: ${COMPOSE_FILE}"
echo ""

if [ -n "${DOMAIN:-}" ]; then
    if [ -f "./certs/${DOMAIN}.crt" ] && [ -f "./certs/${DOMAIN}.key" ]; then
        echo "OK: certificate exists for ${DOMAIN}"
    else
        echo "WARN: certificate files for ${DOMAIN} were not found in ./certs"
        echo "      Leaving ACME helper running is safer until the cert exists."
        exit 1
    fi
fi

echo "Stopping nginx helper containers to save RAM..."
$DOCKER_COMPOSE -f "$COMPOSE_FILE" stop dockergen nginx-proxy-acme 2>/dev/null || true
docker update --restart=no dockergen nginx-proxy-acme >/dev/null 2>&1 || true

echo ""
echo "Done. Nginx and proxy services keep running; only cert/docker-gen helpers are stopped."
echo ""
echo "Before certificate renewal or config changes, re-enable helpers:"
echo "  docker update --restart=always dockergen nginx-proxy-acme"
echo "  $DOCKER_COMPOSE -f $COMPOSE_FILE up -d dockergen nginx-proxy-acme"
echo "  $DOCKER_COMPOSE -f $COMPOSE_FILE restart nginx"
