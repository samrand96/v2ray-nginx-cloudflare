# V2Ray + NGINX + Cloudflare Deployment via Docker

Effortlessly deploy V2Ray with Docker, fully optimized for compatibility with **Cloudflare** and other major **CDNs**.

---

## Project Overview

The **v2ray-nginx-cloudflare** project is designed to streamline the deployment of a secure, scalable V2Ray instance using Docker containers. This architecture enables seamless integration with **Cloudflare** and a wide range of Content Delivery Networks (CDNs), offering enhanced security, obfuscation, and performance.

Whether you're looking to bypass restrictions or simply set up a robust private proxy, this solution is ideal for users who prioritize reliability, compatibility, and ease of deployment.

---

## Key Features

- **V2Ray Integration**: Full support for V2Ray’s inbound and outbound protocols, providing flexible configuration options and advanced routing capabilities.
- **Docker-Based Deployment**: Simplifies installation, management, and scalability with Docker and Docker Compose.
- **Cloudflare & CDN Optimization**: Native support for reverse proxy setups with Cloudflare and other CDNs, improving both security and latency.
- **Let's Encrypt SSL Support**: Automatic HTTPS certificate issuance using Certbot.
- **Scripted Installation**: Optional one-command setup for users who want everything configured automatically.

---

## System Requirements

To get started, make sure you have the following:

- **A VPS (Virtual Private Server)**  
  We **highly recommend Hetzner** for performance and value — they offer:
  
  - 2 vCPU  
  - 4 GB RAM  
  - 20 TB Bandwidth  
  - IPv4 & IPv6 support  
  - All for only **€4.5/month**  
  👉 Sign up and get **€20 credit** here: [https://bit.ly/ssr_vps](https://bit.ly/ssr_vps)

- **Operating System** (any of the following):
  - Ubuntu 12.04 or later
  - Debian 7 or later
  - CentOS 6 or later

- **Root Access** to the server

---

## Manual Installation Guide

Follow these steps to set up your V2Ray server with NGINX and Cloudflare:

1. **Configure DNS**  
   Log into your DNS provider or CDN panel (e.g., Cloudflare) and create an **A record** pointing to your server's IP. Temporarily disable the proxy/CDN feature.

2. **Install Docker**  
   Set up Docker and Docker Compose on your server.

3. **Clone the Repository**  
   Run the following command on your VPS:
   ```bash
   git clone https://github.com/samrand96/v2ray-nginx-cloudflare.git
   cd v2ray-nginx-cloudflare
   ```

4. **Generate a UUID**  
   This will serve as your user identity:
   ```bash
   cat /proc/sys/kernel/random/uuid
   ```

5. **Update V2Ray Config**  
   Replace the placeholder `<UPSTREAM-UUID>` inside `v2ray/config/config.json` with the UUID you generated.

6. **Configure Docker Compose**  
   In `docker-compose.yml`, replace:
   - `YOUR_DOMAIN` with your actual domain or subdomain
   - `YOUR_EMAIL` with your email address (used by Let's Encrypt)

7. **Start Services**  
   Launch everything with:
   ```bash
   docker-compose up -d
   ```

8. **Verify Deployment**  
   Open your domain in a browser to confirm the service is running and serving via HTTPS.

9. **Enable CDN Proxy**  
   Return to your DNS/CDN settings and activate the **proxy/CDN** feature to secure and mask your origin server.

10. **Generate Client Config**  
   Run the following script to generate a V2Ray client configuration:
   ```bash
   ./vmess.py
   ```

---

## One-Command Quick Install

No time to configure everything manually? No worries — run the following command and let the script take care of everything:

```bash
sudo bash <(curl -s https://raw.githubusercontent.com/samrand96/v2ray-nginx-cloudflare/main/easy-install.sh)
```

This will automatically install Docker, configure the services, generate your UUID, obtain SSL certificates, and start the containers. Just plug in your domain when prompted, and you’re ready to go.

---

## Final Notes

This setup provides a powerful, production-ready proxy infrastructure tailored for modern privacy needs and optimized for CDN environments. Whether you’re a seasoned sysadmin or a first-time deployer, this solution ensures a secure and efficient setup with minimal friction.

For questions, improvements, or contributions, feel free to open issues or submit pull requests to the [GitHub repository](https://github.com/samrand96/v2ray-nginx-cloudflare).
