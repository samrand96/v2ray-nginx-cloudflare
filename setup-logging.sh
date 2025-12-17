#!/bin/bash

# Create logs directory structure
echo "📁 Creating logs directory structure..."

# Create main logs directory
mkdir -p logs

# Create subdirectories for each service
mkdir -p logs/nginx
mkdir -p logs/v2ray
mkdir -p logs/docker-gen
mkdir -p logs/acme

# Set proper permissions for log directories
chmod 755 logs
chmod 755 logs/nginx
chmod 755 logs/v2ray
chmod 755 logs/docker-gen
chmod 755 logs/acme

echo "✅ Log directory structure created:"
echo "   📂 logs/"
echo "   ├── 📂 nginx/          (Nginx access and error logs)"
echo "   ├── 📂 v2ray/          (V2Ray access and error logs)"
echo "   ├── 📂 docker-gen/     (Docker-gen logs)"
echo "   └── 📂 acme/           (ACME/Let's Encrypt logs)"
echo ""
echo "📋 Log files will be created automatically when services start:"
echo "   - logs/nginx/access.log           (Standard Nginx access log)"
echo "   - logs/nginx/access_detailed.log  (Detailed Nginx access log)"
echo "   - logs/nginx/error.log            (Nginx error log)"
echo "   - logs/v2ray/access.log           (V2Ray access log)"
echo "   - logs/v2ray/error.log            (V2Ray error log)"
echo "   - logs/docker-gen/docker-gen.log  (Docker-gen logs)"
echo "   - logs/acme/acme.log              (ACME/SSL certificate logs)"
echo ""
echo "🔍 To monitor logs in real-time:"
echo "   tail -f logs/nginx/access.log"
echo "   tail -f logs/v2ray/access.log"
echo "   tail -f logs/nginx/error.log"