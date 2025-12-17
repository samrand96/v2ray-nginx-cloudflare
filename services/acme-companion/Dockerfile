FROM nginxproxy/acme-companion:${ACME_VERSION:-2.2}

# Custom ACME configurations can be added here
# Example: custom renewal scripts, hooks, etc.

LABEL maintainer="your-email@example.com"

# Health check
HEALTHCHECK --interval=60s --timeout=5s --start-period=10s --retries=3 \
    CMD test -f /app/letsencrypt_service_data || exit 1
