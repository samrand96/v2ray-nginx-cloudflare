FROM jwilder/docker-gen:${DOCKER_GEN_VERSION:-0.9}

# Default command (can be overridden)
CMD ["-notify-sighup", "nginx", "-watch", "/etc/docker-gen/templates/nginx.tmpl", "/etc/nginx/conf.d/default.conf"]
