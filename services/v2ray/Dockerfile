FROM v2fly/v2fly-core:${V2RAY_VERSION:-v4.45.2}

# Create log directory
USER root
RUN mkdir -p /var/log/v2ray && chmod 755 /var/log/v2ray

# Health check for multiple ports (using basic commands available in the base image)
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD netstat -tuln | grep -E ":1310|:1311|:1312" || exit 1

# Use default v2ray command
CMD ["v2ray", "-config=/etc/v2ray/config.json"]
