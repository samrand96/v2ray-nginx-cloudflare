FROM v2fly/v2fly-core:${V2RAY_VERSION:-v4.45.2}

# Create log directory
USER root
RUN mkdir -p /var/log/v2ray && chmod 755 /var/log/v2ray

# Health check - verify v2ray process is running
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD pgrep v2ray || exit 1

# Use default v2ray command
CMD ["v2ray", "-config=/etc/v2ray/config.json"]
