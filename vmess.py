#!/usr/bin/python3

"""
Connection Link Generator for VLESS-WS and VLESS-Reality.
Reads configuration from .env and v2ray/config/config.json,
then outputs ready-to-use vless:// share links.
"""

import json
from pathlib import Path
import random
import ipaddress
import sys


def read_env_var(env_file, key, default=""):
    """Read a variable from .env file."""
    if env_file.exists():
        with open(str(env_file), "r") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                if line.startswith(f"{key}="):
                    value = line.split("=", 1)[1].strip()
                    # Strip surrounding quotes
                    if (value.startswith('"') and value.endswith('"')) or (
                        value.startswith("'") and value.endswith("'")
                    ):
                        value = value[1:-1]
                    # Handle inline comments
                    if " #" in value and not value.startswith('"'):
                        value = value.split(" #")[0].strip()
                    return value
    return default


def vless_ws_link(domain, uuid, port="443", ws_path="/", ip=""):
    """Generate VLESS+WS+TLS connection link."""
    address = ip if ip else domain
    encoded_path = ws_path.replace("/", "%2F") if ws_path != "/" else "%2F"
    return (
        f"vless://{uuid}@{address}:{port}"
        f"?type=ws&security=tls&path={encoded_path}"
        f"&host={domain}&sni={domain}&encryption=none"
        f"#{domain}-VLESS-WS"
    )


def vless_reality_link(uuid, server_ip, port, public_key, short_id, server_name, label=""):
    """Generate VLESS+Reality connection link (direct connection, no CDN)."""
    if not public_key or not server_ip:
        return None
    name = label if label else f"{server_ip}-VLESS-Reality"
    return (
        f"vless://{uuid}@{server_ip}:{port}"
        f"?type=tcp&security=reality"
        f"&pbk={public_key}"
        f"&fp=chrome"
        f"&sni={server_name}"
        f"&sid={short_id}"
        f"&flow=xtls-rprx-vision"
        f"#{name}"
    )


# ============================================
# Main
# ============================================
path = Path(__file__).parent
env_file = path / ".env"
config_file = path / "v2ray" / "config" / "config.json"

# Read UUID from config.json
try:
    with open(str(config_file), "r", encoding="utf-8") as f:
        v2ray_config = json.load(f)
    uuid = v2ray_config["inbounds"][0]["settings"]["clients"][0]["id"]
except (FileNotFoundError, KeyError, json.JSONDecodeError) as e:
    print(f"❌ Error reading {config_file}: {e}")
    sys.exit(1)

# Read configuration from .env
domain = read_env_var(env_file, "DOMAIN")
https_port = read_env_var(env_file, "HTTPS_PORT", "443")
reality_port = read_env_var(env_file, "REALITY_PORT", "")
reality_public_key = read_env_var(env_file, "REALITY_PUBLIC_KEY", "")
reality_short_id = read_env_var(env_file, "REALITY_SHORT_ID", "abcd1234")
reality_server_name = read_env_var(env_file, "REALITY_SERVER_NAME", "www.microsoft.com")
vless_ws_path = read_env_var(env_file, "VLESS_WS_PATH", "/")

has_ws = bool(domain)
has_reality = bool(reality_public_key) and reality_public_key != "CHANGE-THIS-PUBLIC-KEY"

if not has_ws and not has_reality:
    print("❌ No valid configuration found in .env")
    print("   Run easy-install.sh first or configure .env manually.")
    sys.exit(1)

# ============================================
# VLESS-WS Link
# ============================================
if has_ws:
    use_cf = input("Are you using Cloudflare CDN Proxy? (yes/no) [no]: ").strip().lower()
    cf_ip = ""
    if use_cf == "yes":
        cf_ip_file = path / "cloudflare_ip_list.txt"
        if cf_ip_file.exists():
            with open(str(cf_ip_file), "r") as f:
                lines = [l.strip() for l in f if l.strip()]
            if lines:
                cidr = random.choice(lines)
                try:
                    network = ipaddress.IPv4Network(cidr, strict=False)
                    hosts = list(network.hosts())
                    if hosts:
                        cf_ip = str(random.choice(hosts))
                except ValueError:
                    pass
            if not cf_ip:
                print("⚠️  Could not pick a Cloudflare IP, using domain directly")
        else:
            print("⚠️  cloudflare_ip_list.txt not found, using domain directly")

    print(f"\n📱 VLESS WebSocket (CDN, port {https_port}):")
    print(vless_ws_link(domain, uuid, https_port, vless_ws_path, cf_ip))

# ============================================
# VLESS-Reality Link
# ============================================
if has_reality:
    if not reality_port:
        reality_port = "443"
    server_ip = input("\nEnter your server IP for VLESS Reality (direct connection): ").strip()
    if not server_ip:
        print("⚠️  No server IP provided. Skipping Reality link.")
    else:
        link = vless_reality_link(
            uuid, server_ip, reality_port,
            reality_public_key, reality_short_id,
            reality_server_name, f"{domain or server_ip}-VLESS-Reality"
        )
        if link:
            print(f"\n📱 VLESS Reality (direct, port {reality_port}):")
            print(link)
        else:
            print("\n❌ Could not generate Reality link.")
            print("   Check that REALITY_PUBLIC_KEY is set in .env")
            print("   You can read the config manually:")
            print("     docker exec v2ray cat /etc/xray/config.json")
            print("   Then build the link:")
            print("     vless://<UUID>@<IP>:<PORT>?type=tcp&security=reality&pbk=<PUB_KEY>&fp=chrome&sni=<SNI>&sid=<SID>&flow=xtls-rprx-vision#<NAME>")
elif not has_ws:
    pass  # Already handled above

print()