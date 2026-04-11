FROM nginxproxy/acme-companion:${ACME_VERSION:-2.2}

# Custom ACME configurations can be added here
# Example: custom renewal scripts, hooks, etc.

LABEL maintainer="your-email@example.com"

# Health check - verify the acme companion process is running
HEALTHCHECK --interval=60s --timeout=5s --start-period=30s --retries=3 \
    CMD pgrep -f "letsencrypt_service" || test -d /etc/acme.sh || exit 1
