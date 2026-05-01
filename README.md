# Xray + Hysteria Proxy via Docker

Deploy a Docker proxy stack with **VLESS + WebSocket + CDN**, **VLESS + XTLS-Reality**, and/or **Hysteria 2**.

The stack is built around one `.env` file. WebSocket mode gets a Let's Encrypt certificate through nginx/acme, and Hysteria reuses that same certificate from `./certs/<domain>.crt` and `./certs/<domain>.key`.

---

## Modes

| Mode | Transport | Public port | Cloudflare/CDN | Domain | Notes |
|---|---|---:|---|---|---|
| VLESS + WS + CDN | WebSocket over TLS | TCP 443 | Yes | Required | Nginx terminates TLS and proxies to Xray |
| VLESS + Reality | TCP + Reality TLS camouflage | TCP 443 or 2083 | No | Not required | Direct to Xray; use server IP |
| Hysteria 2 | QUIC/UDP | UDP 443 | No | Required for cert/SNI | Direct UDP; reuses the nginx/acme cert |

You can install one mode, WS + Reality together, or all three together.

---

## Quick Install

Run the current branch installer:

```bash
sudo env REPO_BRANCH=backup bash <(curl -fsSL https://raw.githubusercontent.com/samrand96/v2ray-nginx-cloudflare/backup/install.sh)
```

The installer asks you to choose:

1. `VLESS + WebSocket + CDN`
2. `VLESS + XTLS-Reality`
3. `Hysteria 2` only, using an existing cert in `./certs`
4. `WS + Reality`
5. `All three`

For Hysteria-only, run WS/Both/All first or copy an existing certificate into `./certs` before starting Hysteria.

---

## How It Works

### VLESS + WebSocket + CDN

```text
Client -> Cloudflare/CDN -> Nginx TLS -> Xray VLESS-WS on 1310
```

Use this when you want CDN-fronted HTTPS traffic. During certificate issuance, keep the DNS record pointed to the server and disable Cloudflare proxy until Let's Encrypt succeeds.

### VLESS + XTLS-Reality

```text
Client -> Xray Reality TCP port
```

Use this direct to the server IP. Do not put Reality behind nginx or Cloudflare.

### Hysteria 2

```text
Client -> Hysteria UDP port -> direct IPv4 outbound
```

Hysteria uses the same certificate files that nginx/acme created for your domain. It can share numeric port `443` with nginx because nginx listens on TCP and Hysteria listens on UDP. Cloudflare proxy does not carry this UDP traffic, so connect to the server IP or a DNS-only hostname and keep SNI set to the certificate domain.

---

## Project Structure

```text
.env                                  # Generated runtime configuration
.env.example                          # Example configuration
install.sh                            # Main interactive installer
install-hysteria.sh                   # Standalone Hysteria installer
generate-config.sh                    # Regenerate Xray config from .env
generate-hysteria-config.sh           # Regenerate Hysteria config from .env
docker-compose.yml                    # WS-only stack
docker-compose.reality.yml            # Reality-only stack
docker-compose.modular.yml            # WS + Reality stack
docker-compose.hysteria.yml           # Hysteria-only stack
hysteria/config.template.yaml         # Hysteria template
hysteria/config.yaml                  # Generated Hysteria config, ignored by git
vhost/default                         # Server-level nginx include
vhost/default_location                # Location-level nginx include
v2ray/config/*.template.json          # Xray templates
v2ray/config/config.json              # Generated Xray config, ignored by git
```

---

## Client Links

### VLESS + WebSocket

```text
vless://<UUID>@<CLOUDFLARE-IP>:443?type=ws&security=tls&path=%2F&host=<DOMAIN>&sni=<DOMAIN>&encryption=none#VLESS-WS
```

Settings: network `ws`, path `/`, TLS enabled, Host/SNI set to your domain.

### VLESS + Reality

```text
vless://<UUID>@<SERVER-IP>:<REALITY-PORT>?type=tcp&security=reality&pbk=<PUBLIC-KEY>&fp=chrome&sni=<REALITY-SNI>&sid=<SHORT-ID>&flow=xtls-rprx-vision#VLESS-Reality
```

Settings: address is the server IP, not the CDN domain. Use the generated public key, short ID, and Reality SNI from `.env`.

### Hysteria 2

```text
hysteria2://<PASSWORD>@<SERVER-IP>:<UDP-PORT>/?sni=<DOMAIN>#Hysteria2
```

Settings: address is the server IP or a DNS-only hostname, SNI is the domain whose cert exists in `./certs`, and the firewall must allow UDP on the chosen port.

---

## Manual Commands

Regenerate Xray:

```bash
./generate-config.sh
docker compose -f docker-compose.modular.yml restart v2ray
```

Regenerate Hysteria:

```bash
./generate-hysteria-config.sh
docker compose -f docker-compose.hysteria.yml restart hysteria
```

Install Hysteria separately after certs exist:

```bash
sudo bash install-hysteria.sh
```

View logs:

```bash
docker compose -f docker-compose.modular.yml logs -f
docker compose -f docker-compose.hysteria.yml logs -f hysteria
```

---

## Troubleshooting

### Nginx/WS

```bash
docker compose -f docker-compose.modular.yml ps
docker compose -f docker-compose.modular.yml logs nginx
docker compose -f docker-compose.modular.yml logs nginx-proxy-acme
docker compose -f docker-compose.modular.yml exec nginx nginx -t
```

If ACME fails, confirm port `80/tcp` is open, DNS points to the server IP, and Cloudflare proxy is disabled during issuance.

### Reality

```bash
grep REALITY .env
docker compose -f docker-compose.modular.yml logs -f v2ray
ss -lntp | grep -E ':(443|2083)\b'
```

Reality must be tested against the server IP and the exact generated `REALITY_PUBLIC_KEY`, `REALITY_SHORT_ID`, and `REALITY_SERVER_NAME`.

### Hysteria

```bash
grep HYSTERIA .env
ls -l certs/${DOMAIN}.crt certs/${DOMAIN}.key
docker compose -f docker-compose.hysteria.yml ps
docker compose -f docker-compose.hysteria.yml logs -f hysteria
ss -lunp | grep ":${HYSTERIA_PORT:-443}"
```

If Hysteria does not connect, check that UDP is open on the server firewall/provider firewall. If the domain is orange-cloud proxied in Cloudflare, still use the server IP as the client address and set `sni=<DOMAIN>`.

---

## Uninstall

```bash
docker compose -f docker-compose.modular.yml down
docker compose -f docker-compose.reality.yml down
docker compose -f docker-compose.hysteria.yml down
```
