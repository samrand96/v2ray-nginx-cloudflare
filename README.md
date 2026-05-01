# Xray Proxy — VLESS-WS + VLESS-Reality via Docker

Deploy an Xray proxy server with Docker supporting **VLESS + WebSocket + CDN** and/or **VLESS + XTLS-Reality** (direct connection). Fully optimized for **Cloudflare** and other major CDNs.

---

## Two Deployment Modes

| | VLESS + WS + CDN | VLESS + XTLS-Reality |
|---|---|---|
| **Transport** | WebSocket over TLS | TCP with Reality TLS camouflage |
| **Domain required** | Yes | No |
| **CDN/Cloudflare** | Yes (recommended) | No — direct connection |
| **Nginx required** | Yes | No |
| **Anti-censorship** | Good | Excellent |
| **Performance** | Excellent | Excellent |

You can run **either mode alone** or **both simultaneously** (dual-mode). When running both, Reality uses its own dedicated port.

---

## Quick Install

One command — detects your system, installs Docker, and sets up everything:

```bash
sudo bash <(curl -s https://raw.githubusercontent.com/samrand96/v2ray-nginx-cloudflare/main/easy-install.sh)
```

The script will ask you to choose:

1. **VLESS + WS + CDN** — requires a domain pointed to your server
2. **VLESS + XTLS-Reality** — direct connection, no domain needed
3. **Both** — requires domain + a separate port for Reality

---

## How It Works

### Mode 1: VLESS + WebSocket + CDN

Traffic flows through Cloudflare CDN:

```
Client → Cloudflare CDN → Nginx (TLS termination) → Xray (VLESS-WS on port 1310)
```

- Nginx handles TLS certificates via Let's Encrypt (ACME)
- WebSocket traffic on path `/` is reverse-proxied to Xray
- External port: 443 (HTTPS)

### Mode 2: VLESS + XTLS-Reality

Traffic connects directly to your server:

```
Client → Xray (VLESS-Reality with TLS camouflage)
```

- No nginx, no CDN — Xray handles everything
- Reality makes your server look like a legitimate website (e.g. microsoft.com)
- External port: configurable (default 443 standalone, 2083 in dual-mode)

### Dual Mode (Both)

Both protocols run simultaneously in the same Xray container:

- VLESS-WS on internal port 1310 (proxied by nginx on port 443)
- VLESS-Reality on internal port 1313 (exposed directly on your chosen Reality port)

---

## Project Structure

```
.env                              # All configuration (single source of truth)
docker-compose.yml                # WS-only mode (nginx + xray)
docker-compose.modular.yml        # Dual mode (nginx + xray with WS + Reality)
docker-compose.reality.yml        # Reality-only mode (xray only)
easy-install.sh                   # Interactive setup script
generate-config.sh                # Regenerate xray config from .env
vmess.py                          # Generate connection share links
vhost/default                     # Safe server-level nginx include (no location blocks)
vhost/default_location            # WebSocket timeout overrides inside generated location /
v2ray/config/
├── config.template.json          # Xray template (WS + Reality)
├── config.no-reality.template.json   # Xray template (WS only)
├── config.reality-only.template.json # Xray template (Reality only)
└── config.json                   # Generated runtime config
```

---

## Client Configuration

### VLESS + WebSocket (CDN)

```
vless://<UUID>@<CLOUDFLARE-IP>:443?type=ws&security=tls&path=%2F&host=<DOMAIN>&sni=<DOMAIN>&encryption=none#VLESS-WS
```

**Settings:**
- Address: your domain (or Cloudflare IP)
- Port: 443
- UUID: your generated UUID
- Network: ws
- Security: tls
- Path: /
- SNI/Host: your domain

### VLESS + XTLS-Reality (Direct)

```
vless://<UUID>@<SERVER-IP>:<REALITY-PORT>?type=tcp&security=reality&pbk=<PUBLIC-KEY>&fp=chrome&sni=<SNI>&sid=<SHORT-ID>&flow=xtls-rprx-vision#VLESS-Reality
```

**Settings:**
- Address: your server IP (NOT domain)
- Port: your Reality port
- UUID: your generated UUID
- Network: tcp
- Security: reality
- Flow: xtls-rprx-vision
- Public Key: from setup output
- Fingerprint: chrome
- SNI: the Reality destination domain (e.g. www.microsoft.com)
- Short ID: from setup output

### Recommended Client Apps

| Platform | App |
|---|---|
| Android | v2rayNG, Clash Meta |
| iOS | Shadowrocket, Streisand |
| Windows | v2rayN, Clash Verge, NekoRay |
| macOS | Clash Verge, V2RayXS |
| Linux | NekoRay, Clash Verge |

---

## Manual Installation

### 1. Prepare DNS (WS mode only)

Create an A record pointing your domain to your server IP. Temporarily disable Cloudflare proxy (grey cloud).

### 2. Install Docker

```bash
curl -fsSL https://get.docker.com | sudo bash
```

### 3. Clone & Configure

```bash
git clone https://github.com/samrand96/v2ray-nginx-cloudflare.git
cd v2ray-nginx-cloudflare

# Run the interactive setup
sudo bash easy-install.sh
```

### 4. Enable Cloudflare CDN (WS mode)

After setup completes and SSL certificates are issued, enable Cloudflare proxy (orange cloud).

---

## Configuration Reference

All settings are in the `.env` file:

```bash
# UUID
V2RAY_UUID=your-uuid-here

# Domain (WS mode)
DOMAIN=your-domain.com
LETSENCRYPT_EMAIL=your@email.com
HTTPS_PORT=443

# Reality settings
REALITY_PORT=2083
REALITY_DEST=www.microsoft.com:443
REALITY_SERVER_NAME=www.microsoft.com
REALITY_PRIVATE_KEY=your-private-key
REALITY_PUBLIC_KEY=your-public-key
REALITY_SHORT_ID=your-short-id
```

After editing `.env`, regenerate the Xray config:

```bash
./generate-config.sh
docker compose -f docker-compose.modular.yml restart v2ray
```

---

## Management Commands

```bash
# View status
docker compose -f <COMPOSE-FILE> ps

# View logs
docker compose -f <COMPOSE-FILE> logs -f v2ray

# Restart
docker compose -f <COMPOSE-FILE> restart

# Stop
docker compose -f <COMPOSE-FILE> down

# Get connection links
python3 vmess.py

# Test xray config
docker compose -f <COMPOSE-FILE> exec v2ray xray run -test -c /etc/xray/config.json
```

Replace `<COMPOSE-FILE>` with your compose file (`docker-compose.yml`, `docker-compose.modular.yml`, or `docker-compose.reality.yml`).

---

## Troubleshooting

### Connection Issues

```bash
# Check all containers are running
docker compose -f <COMPOSE-FILE> ps

# Check xray logs
docker compose -f <COMPOSE-FILE> logs v2ray

# Check nginx logs (WS mode)
docker compose -f <COMPOSE-FILE> logs nginx

# Verify xray config
docker compose -f <COMPOSE-FILE> exec v2ray cat /etc/xray/config.json
```

### SSL Certificate Issues (WS mode)

```bash
# Check ACME logs
docker compose -f <COMPOSE-FILE> logs nginx-proxy-acme

# Ensure port 80 is open (required for Let's Encrypt HTTP-01 challenge)
# Ensure DNS A record points to server and Cloudflare proxy is OFF during setup
```

### Reality Issues

```bash
# Verify Reality keys were generated
grep REALITY .env

# Test from client: ensure server IP, port, public key, SNI, and short ID match
# Ensure the Reality port is open in your firewall
```

---

## Security Notes

- Always generate a unique UUID for each deployment
- Generate unique x25519 keys: `docker run --rm ghcr.io/xtls/xray-core x25519`
- Use Cloudflare "Full (strict)" SSL mode for WS
- Only expose necessary ports (80 for ACME, HTTPS port, Reality port)
- Monitor logs regularly for suspicious activity

---

## Supported Systems

Ubuntu, Debian, CentOS, RHEL, Rocky Linux, AlmaLinux, Fedora, Arch Linux, Manjaro, Alpine Linux, openSUSE.

Minimum: 1 CPU, 512MB RAM, 2GB storage.

---

## License

See [LICENSE](LICENSE) for details.
