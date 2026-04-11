# V2Ray + NGINX + Cloudflare Deployment via Docker

Effortlessly deploy V2Ray with Docker, featuring **multi-protocol support** and fully optimized for compatibility with **Cloudflare** and other major **CDNs**.

---

## Project Overview

The **v2ray-nginx-cloudflare** project provides both **original** and **modular** deployment options for a secure, scalable V2Ray instance using Docker containers. This architecture enables seamless integration with **Cloudflare** and CDNs, offering enhanced security, obfuscation, and performance.

### 🎯 **Two Setup Options:**

1. **🔄 Original Setup** - Simple VLESS-only configuration (recommended for basic use)
2. **🆕 Modular Setup** - Multi-protocol support with VLESS, VMess, and advanced customization

Whether you're looking to bypass restrictions or set up a robust private proxy, this solution prioritizes reliability, compatibility, and ease of deployment.

---

## 🚀 **Quick Install (Recommended)**

**One-command installation** - automatically detects your system and sets up everything:

```bash
sudo bash <(curl -s https://raw.githubusercontent.com/samrand96/v2ray-nginx-cloudflare/main/easy-install.sh)
```

**What it does:**
- ✅ Detects your Linux distribution (Ubuntu, Debian, CentOS, Fedora, Arch, Alpine, etc.)
- ✅ Installs Docker and Docker Compose if needed
- ✅ Lets you choose between original or modular setup
- ✅ Configures multi-protocol support (VLESS+VMess)
- ✅ Generates UUID and client configurations
- ✅ Sets up SSL certificates automatically
- ✅ Provides ready-to-use connection links

---

## 🌟 **Multi-Protocol Support (New!)**

The modular setup supports **three Cloudflare-compatible protocols**:

### **🥇 VLESS + WebSocket + TLS (Best for CDN)**
- **Port:** 1310
- **Path:** `/` 
- **Performance:** ⭐⭐⭐⭐⭐
- **CDN Compatible:** ✅ Excellent

### **🥈 VLESS + gRPC + TLS**
- **Port:** 1311
- **Service:** `grpc`
- **Performance:** ⭐⭐⭐⭐
- **CDN Compatible:** ✅ Good

### **🥉 VMess + WebSocket + TLS**
- **Port:** 1312
- **Path:** `/ws`
- **Performance:** ⭐⭐⭐
- **CDN Compatible:** ✅ Good (Legacy)

---

## 📦 **Modular Architecture**

```
v2ray-nginx-cloudflare/
├── .env                          # ⭐ SINGLE source of truth (all config here)
├── .env.example                  # Configuration template
├── docker-compose.modular.yml    # Multi-protocol setup
├── docker-compose.yml            # Original setup (preserved)
├── generate-config.sh            # Script to regenerate V2Ray config
├── vhost/
│   └── default                   # Nginx location blocks for all protocols
├── configs/
│   └── nginx.tmpl                # Nginx-proxy template
└── v2ray/config/
    ├── config.template.json      # V2Ray config template
    └── config.json               # Generated V2Ray config
```

### **🎛️ Centralized Configuration:**
- **Single `.env` file** - All services read from one place
- **No duplicate configs** - Change once, apply everywhere
- **Easy management** - Edit `.env` and restart services
- **Version control** - All settings in environment variables

---

## 🐧 **System Requirements & Compatibility**

### **Supported Linux Distributions:**
- ✅ **Ubuntu** (18.04, 20.04, 22.04, 24.04+)
- ✅ **Debian** (9, 10, 11, 12+)
- ✅ **CentOS/RHEL** (7, 8, 9)
- ✅ **Rocky Linux / AlmaLinux**
- ✅ **Fedora** (35+)
- ✅ **Arch Linux / Manjaro**
- ✅ **Alpine Linux**
- ✅ **openSUSE / SLES**

### **Hardware Requirements:**
- **CPU:** 1+ cores
- **RAM:** 512MB+ (1GB+ recommended)
- **Storage:** 2GB+ free space
- **Network:** Public IP with port 80/443 access

### **Recommended VPS:**
**Hetzner** offers excellent performance and value:
- 2 vCPU, 4 GB RAM, 20 TB Bandwidth
- IPv4 & IPv6 support
- **€4.5/month** with **€20 credit**: [https://bit.ly/ssr_vps](https://bit.ly/ssr_vps)

---

## 📱 **Client Configurations**

### **Quick Connection Links:**

Replace `your-domain.com` and `your-uuid` with your actual values:

#### **VLESS WebSocket (Recommended):**
```
vless://your-uuid@your-domain.com:443?type=ws&security=tls&path=%2F&host=your-domain.com&sni=your-domain.com&encryption=none#VLESS-WS
```

#### **VLESS gRPC:**
```
vless://your-uuid@your-domain.com:443?type=grpc&security=tls&serviceName=grpc&host=your-domain.com&sni=your-domain.com#VLESS-gRPC
```

#### **VMess WebSocket:**
```
vmess://eyJ2IjoiMiIsInBzIjoiVk1lc3MtV1MiLCJhZGQiOiJ5b3VyLWRvbWFpbi5jb20iLCJwb3J0IjoiNDQzIiwidHlwZSI6Im5vbmUiLCJpZCI6InlvdXItdXVpZCIsImFpZCI6IjAiLCJuZXQiOiJ3cyIsInBhdGgiOiIvd3MiLCJob3N0IjoieW91ci1kb21haW4uY29tIiwidGxzIjoidGxzIn0=
```

### **📱 Recommended Client Apps:**

#### **Android:**
- **v2rayNG** - Supports all protocols
- **Clash Meta for Android** - Modern and user-friendly

#### **iOS:**
- **OneClick** - Supports VLESS and VMess
- **Shadowrocket** - Paid but excellent

#### **Desktop:**
- **V2Ray Desktop** - Official client
- **Clash Verge** - Modern GUI with Clash Meta core
- **NekoRay** - Feature-rich client

---

## 🛠️ **Manual Installation Guide**

If you prefer manual setup or need custom configuration:

### **1. Prepare DNS**
Create an **A record** pointing to your server's IP. Temporarily disable CDN proxy.

### **2. Install Docker**
```bash
# Download and run our universal installer
curl -fsSL https://raw.githubusercontent.com/samrand96/v2ray-nginx-cloudflare/main/install-docker.sh | sudo bash
```

### **3. Clone Repository**
```bash
git clone https://github.com/samrand96/v2ray-nginx-cloudflare.git
cd v2ray-nginx-cloudflare
```

### **4. Choose Setup Type**

#### **Option A: Modular Setup (Recommended)**
```bash
# Copy environment template
cp .env.example .env

# Generate UUID
UUID=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid)

# Edit the SINGLE configuration file
nano .env  # Set DOMAIN, LETSENCRYPT_EMAIL, and V2RAY_UUID

# Generate V2Ray config from template
./generate-config.sh

# Start all services
docker compose -f docker-compose.modular.yml up -d
```

#### **Option B: Original Setup (VLESS only)**
```bash
# Generate UUID
UUID=$(uuidgen)

# Update config
sed -i "s/<UPSTREAM-UUID>/$UUID/g" v2ray/config/config.json

# Edit docker-compose.yml: Set DOMAIN and EMAIL
nano docker-compose.yml

# Start services
docker compose up -d
```

### **5. Enable Cloudflare CDN**
Return to your DNS settings and **enable the proxy/CDN** feature.

---

## 🔧 **Advanced Configuration**

### **Centralized Configuration (Modular Setup):**
All configuration is in the root `.env` file:
```bash
# Domain and SSL
DOMAIN=your-domain.com
LETSENCRYPT_EMAIL=your@email.com

# V2Ray UUID (generate with: uuidgen)
V2RAY_UUID=your-uuid-here

# Protocol ports (fixed in vhost/default)
VLESS_WS_PORT=1310      # VLESS WebSocket
VLESS_GRPC_PORT=1311    # VLESS gRPC
VMESS_WS_PORT=1312      # VMess WebSocket

# Protocol paths
VLESS_WS_PATH=/
VLESS_GRPC_SERVICE=grpc
VMESS_WS_PATH=/ws
```

After editing `.env`, regenerate V2Ray config:
```bash
./generate-config.sh
docker compose -f docker-compose.modular.yml restart v2ray
```

### **Resource Limits:**
Add to `.env` file:
```bash
CPU_LIMIT=1.0
MEMORY_LIMIT=512M
MEMORY_RESERVATION=256M
```

### **Service Management:**
```bash
# Individual service control
docker compose -f docker-compose.modular.yml stop v2ray
docker compose -f docker-compose.modular.yml start nginx
docker compose -f docker-compose.modular.yml restart nginx-proxy-acme

# Rebuild and restart
docker compose -f docker-compose.modular.yml up -d --force-recreate

# View logs
docker compose -f docker-compose.modular.yml logs -f v2ray
docker compose -f docker-compose.modular.yml logs -f nginx
```

---

## 🔐 **Security Best Practices**

1. **🆔 Unique UUID:** Always generate a new UUID for V2Ray
2. **🔒 Strong SSL:** Use "Full (strict)" mode in Cloudflare
3. **📊 Monitor logs:** Regularly check for suspicious activity
4. **🔄 Keep updated:** Update service versions in `.env` files
5. **🛡️ Firewall:** Only expose necessary ports (80, 443)

---

## 🐛 **Troubleshooting**

### **Connection Issues:**
```bash
# Check service status
docker compose -f docker-compose.modular.yml ps

# View all logs
docker compose -f docker-compose.modular.yml logs

# Test configuration
docker compose -f docker-compose.modular.yml exec v2ray v2ray -test -config /etc/v2ray/config.json
```

### **Certificate Issues:**
```bash
# Check ACME logs
docker compose -f docker-compose.modular.yml logs nginx-proxy-acme

# Force renewal
docker compose -f docker-compose.modular.yml exec nginx-proxy-acme /app/force_renew
```

### **Clean Restart:**
```bash
# Stop all services
docker compose -f docker-compose.modular.yml down

# Clean rebuild
docker compose -f docker-compose.modular.yml build --no-cache
docker compose -f docker-compose.modular.yml up -d
```

### 1. Check if all containers are running
```bash
docker compose -f docker-compose.modular.yml ps
```

### 2. Check V2Ray container logs
```bash
docker compose -f docker-compose.modular.yml logs v2ray
```

### 3. Check nginx logs
```bash
docker compose -f docker-compose.modular.yml logs nginx
```

### 4. Check docker-gen logs
```bash
docker compose -f docker-compose.modular.yml logs dockergen
```

### 5. Check if V2Ray is listening on the correct ports
```bash
docker compose -f docker-compose.modular.yml exec v2ray netstat -tlnp
```

### 6. Test V2Ray connectivity from nginx container
```bash
docker compose -f docker-compose.modular.yml exec nginx curl -I http://v2ray:1310
```

### 7. Check generated nginx configuration
```bash
docker compose -f docker-compose.modular.yml exec nginx cat /etc/nginx/conf.d/default.conf
```

### 8. Check if V2Ray config was generated properly
```bash
docker compose -f docker-compose.modular.yml exec v2ray cat /etc/v2ray/config.json
```

---

## 📊 **Performance Comparison**

| Protocol | Speed | CPU Usage | Compatibility | Cloudflare CDN |
|----------|-------|-----------|---------------|----------------|
| VLESS+WS | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ✅ Excellent |
| VLESS+gRPC | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ | ✅ Good |
| VMess+WS | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ✅ Good |

---

## 🆚 **Setup Comparison**

| Feature | Original Setup | Modular Setup |
|---------|----------------|---------------|
| **Protocols** | VLESS only | VLESS + VMess + gRPC |
| **Customization** | Limited | Extensive |
| **Performance** | Good | Excellent |
| **Maintenance** | Manual | Automated |
| **CDN Optimization** | Basic | Advanced |
| **Resource Control** | No | Yes |

---

## 🎯 **Detailed Client Configurations**

### **VLESS + WebSocket + TLS (Recommended)**

**Connection Details:**
- **Server:** your-domain.com
- **Port:** 443
- **UUID:** your-generated-uuid
- **Network:** ws
- **Path:** /
- **TLS:** true

#### **V2Ray Client JSON:**
```json
{
  "outbounds": [{
    "protocol": "vless",
    "settings": {
      "vnext": [{
        "address": "your-domain.com",
        "port": 443,
        "users": [{
          "id": "your-generated-uuid",
          "encryption": "none"
        }]
      }]
    },
    "streamSettings": {
      "network": "ws",
      "security": "tls",
      "wsSettings": {
        "path": "/",
        "headers": {
          "Host": "your-domain.com"
        }
      },
      "tlsSettings": {
        "serverName": "your-domain.com"
      }
    }
  }]
}
```

#### **Clash Meta YAML:**
```yaml
proxies:
  - name: "VLESS-WS"
    type: vless
    server: your-domain.com
    port: 443
    uuid: your-generated-uuid
    network: ws
    tls: true
    ws-opts:
      path: /
      headers:
        Host: your-domain.com
```

### **VLESS + gRPC + TLS**

**Connection Details:**
- **Server:** your-domain.com
- **Port:** 443
- **UUID:** your-generated-uuid
- **Network:** grpc
- **Service:** grpc
- **TLS:** true

#### **V2Ray Client JSON:**
```json
{
  "outbounds": [{
    "protocol": "vless",
    "settings": {
      "vnext": [{
        "address": "your-domain.com",
        "port": 443,
        "users": [{
          "id": "your-generated-uuid",
          "encryption": "none"
        }]
      }]
    },
    "streamSettings": {
      "network": "grpc",
      "security": "tls",
      "grpcSettings": {
        "serviceName": "grpc"
      },
      "tlsSettings": {
        "serverName": "your-domain.com"
      }
    }
  }]
}
```

### **VMess + WebSocket + TLS**

**Connection Details:**
- **Server:** your-domain.com
- **Port:** 443
- **UUID:** your-generated-uuid
- **AlterID:** 0
- **Network:** ws
- **Path:** /ws
- **TLS:** true

#### **V2Ray Client JSON:**
```json
{
  "outbounds": [{
    "protocol": "vmess",
    "settings": {
      "vnext": [{
        "address": "your-domain.com",
        "port": 443,
        "users": [{
          "id": "your-generated-uuid",
          "alterId": 0,
          "security": "auto"
        }]
      }]
    },
    "streamSettings": {
      "network": "ws",
      "security": "tls",
      "wsSettings": {
        "path": "/ws",
        "headers": {
          "Host": "your-domain.com"
        }
      },
      "tlsSettings": {
        "serverName": "your-domain.com"
      }
    }
  }]
}
```

---

## 📚 **Additional Resources**

- **V2Ray Documentation:** [https://www.v2ray.com/](https://www.v2ray.com/)
- **Nginx Documentation:** [https://nginx.org/en/docs/](https://nginx.org/en/docs/)
- **Let's Encrypt:** [https://letsencrypt.org/docs/](https://letsencrypt.org/docs/)
- **Docker Compose:** [https://docs.docker.com/compose/](https://docs.docker.com/compose/)

---

## 🤝 **Contributing**

We welcome contributions! For issues, improvements, or new features:

1. **Fork** the repository
2. **Create** a feature branch
3. **Submit** a pull request

For questions or support, open an issue in the [GitHub repository](https://github.com/samrand96/v2ray-nginx-cloudflare).

---

## 📄 **License**

This project is licensed under the terms specified in the LICENSE file.
