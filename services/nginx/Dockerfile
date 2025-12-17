FROM nginx:${NGINX_VERSION:-1.22}

# Copy basic nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Health check (using wget which is available by default)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost/ || exit 1

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]
