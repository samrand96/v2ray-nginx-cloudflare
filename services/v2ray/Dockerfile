FROM ghcr.io/xtls/xray-core:${XRAY_VERSION:-latest}

# Create log directory
USER root
RUN mkdir -p /var/log/v2ray && chmod 755 /var/log/v2ray

# Health check - verify xray process is running
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD pgrep xray || exit 1

# Use xray command (backward compatible with v2ray configs)
CMD ["xray", "run", "-c", "/etc/xray/config.json"]
