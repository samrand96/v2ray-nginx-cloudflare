#!/usr/bin/python3

import base64
import json
from pathlib import Path
import random
import ipaddress
import os

def read_env_var(env_file, key, default=""):
    """Read a variable from .env file."""
    if env_file.exists():
        with open(str(env_file), 'r') as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                if line.startswith(f'{key}='):
                    value = line.split('=', 1)[1].strip()
                    # Strip surrounding quotes
                    if (value.startswith('"') and value.endswith('"')) or \
                       (value.startswith("'") and value.endswith("'")):
                        value = value[1:-1]
                    # Handle inline comments
                    if ' #' in value and not value.startswith('"'):
                        value = value.split(' #')[0].strip()
                    return value
    return default

def vless_config_generator(domain, uuid, port="443", ws_path="/", ip=""):
    if ip == "":
        ip = domain
    name = domain
    encoded_path = ws_path.replace("/", "%2F") if ws_path != "/" else "%2F"
    return f"vless://{uuid}@{ip}:{port}?type=ws&security=tls&path={encoded_path}&host={domain}&sni={domain}&encryption=none#{name}-VLESS-WS"

def vmess_config_generator(domain, uuid, port="443", ws_path="/ws", ip=""):
    if ip == "":
        ip = domain
    name = domain
    j = json.dumps({
        "v": "2", "ps": f"{name}-VMess-WS", "add": ip, "port": port, "id": uuid,
        "aid": "0", "net": "ws", "type": "none", "sni": domain,
        "host": domain, "path": ws_path, "tls": "tls"
    })
    return "vmess://" + base64.b64encode(j.encode('ascii')).decode('ascii')

def reality_config_generator(uuid, server_ip, reality_port, public_key, short_id, server_name, name_prefix=""):
    """Generate VLESS+Reality connection link (direct connection, no CDN)."""
    name = f"{name_prefix}-VLESS-Reality" if name_prefix else f"{server_ip}-VLESS-Reality"
    return (
        f"vless://{uuid}@{server_ip}:{reality_port}"
        f"?type=tcp&security=reality"
        f"&pbk={public_key}"
        f"&fp=chrome"
        f"&sni={server_name}"
        f"&sid={short_id}"
        f"&flow=xtls-rprx-vision"
        f"#{name}"
    )


path = Path(__file__).parent
env_file = path.joinpath('.env')
v2ray_config_file = open(str(path.joinpath('v2ray/config/config.json')), 'r', encoding='utf-8')
v2ray_config = json.load(v2ray_config_file)

uuid = v2ray_config['inbounds'][0]['settings']['clients'][0]['id']

# Read configuration from .env
domain = read_env_var(env_file, 'DOMAIN')
https_port = read_env_var(env_file, 'HTTPS_PORT', '443')
reality_port = read_env_var(env_file, 'REALITY_PORT', '2083')
reality_public_key = read_env_var(env_file, 'REALITY_PUBLIC_KEY', '')
reality_short_id = read_env_var(env_file, 'REALITY_SHORT_ID', 'abcd1234')
reality_server_name = read_env_var(env_file, 'REALITY_SERVER_NAME', 'www.microsoft.com')
vless_ws_path = read_env_var(env_file, 'VLESS_WS_PATH', '/')
vmess_ws_path = read_env_var(env_file, 'VMESS_WS_PATH', '/ws')

# Fall back to docker-compose.yml if no .env
if not domain:
    try:
        import yaml
        with open(str(path.joinpath('docker-compose.yml')), 'r') as f:
            dockerCompose = yaml.safe_load(f)
        for env_var in dockerCompose["services"]["v2ray"]["environment"]:
            if "VIRTUAL_HOST=" in env_var:
                domain = env_var.split('=', 1)[1]
                break
    except Exception:
        domain = input("Enter your domain: ")

if not domain:
    domain = input("Enter your domain: ")

isUsingCloudFlareCDNProxy = input("Are you using CloudFlare CDN Proxy? type 'yes' or 'no'. Default is no.\n")
if isUsingCloudFlareCDNProxy == 'yes':
    cf_ip_file = path.joinpath('cloudflare_ip_list.txt')
    if cf_ip_file.exists():
        for line in open(str(cf_ip_file), 'r'):
            tempIpList = []
            for tempIP in ipaddress.IPv4Network(str(line).strip()):
                tempIpList.append(tempIP)
            finalIP = str(random.choice(tempIpList)).strip()
            print(f"\n📱 VLESS WebSocket (CDN, port {https_port}):")
            print(vless_config_generator(domain, uuid, https_port, vless_ws_path, finalIP))
            print(f"\n📱 VMess WebSocket (CDN, port {https_port}):")
            print(vmess_config_generator(domain, uuid, https_port, vmess_ws_path, finalIP) + "\n")
    else:
        print("cloudflare_ip_list.txt not found, using domain directly")
        print(f"\n📱 VLESS WebSocket (CDN, port {https_port}):")
        print(vless_config_generator(domain, uuid, https_port, vless_ws_path))
        print(f"\n📱 VMess WebSocket (CDN, port {https_port}):")
        print(vmess_config_generator(domain, uuid, https_port, vmess_ws_path))
else:
    print(f"\n📱 VLESS WebSocket (port {https_port}):")
    print(vless_config_generator(domain, uuid, https_port, vless_ws_path))
    print(f"\n📱 VMess WebSocket (port {https_port}):")
    print(vmess_config_generator(domain, uuid, https_port, vmess_ws_path))

# Always show Reality link (direct connection, no CDN)
if reality_public_key and reality_public_key != 'CHANGE-THIS-PUBLIC-KEY':
    # Get server IP for Reality (direct connection)
    server_ip = input("\nEnter your server IP for VLESS Reality (direct connection, no CDN): ")
    if server_ip:
        print(f"\n📱 VLESS Reality (direct, port {reality_port}):")
        print(reality_config_generator(
            uuid, server_ip, reality_port,
            reality_public_key, reality_short_id,
            reality_server_name, domain
        ))
else:
    print("\n⚠️  Reality not configured. Set REALITY_PUBLIC_KEY in .env to enable.")
