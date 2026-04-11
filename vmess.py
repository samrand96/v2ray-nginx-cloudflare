#!/usr/bin/python3

import base64
import json
from pathlib import Path
import random
import ipaddress

def vless_config_generator(domain, uuid, ip=""):
    if ip == "":
        ip = domain
    name = domain
    return f"vless://{uuid}@{ip}:443?type=ws&security=tls&path=%2F&host={domain}&sni={domain}&encryption=none#{name}-VLESS-WS"

def vmess_config_generator(domain, uuid, ip=""):
    if ip == "":
        ip = domain
    name = domain
    j = json.dumps({
        "v": "2", "ps": f"{name}-VMess-WS", "add": ip, "port": "443", "id": uuid,
        "aid": "0", "net": "ws", "type": "none", "sni": domain,
        "host": domain, "path": "/ws", "tls": "tls"
    })
    return "vmess://" + base64.b64encode(j.encode('ascii')).decode('ascii')


path = Path(__file__).parent
v2ray_config_file = open(str(path.joinpath('v2ray/config/config.json')), 'r', encoding='utf-8')
v2ray_config = json.load(v2ray_config_file)

uuid = v2ray_config['inbounds'][0]['settings']['clients'][0]['id']

# Try to read domain from .env first, fall back to docker-compose.yml
domain = None
env_file = path.joinpath('.env')
if env_file.exists():
    with open(str(env_file), 'r') as f:
        for line in f:
            line = line.strip()
            if line.startswith('DOMAIN=') and not line.startswith('#'):
                domain = line.split('=', 1)[1].strip()
                break

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
            print("\n📱 VLESS WebSocket (Recommended):")
            print(vless_config_generator(domain, uuid, finalIP))
            print("\n📱 VMess WebSocket (Legacy):")
            print(vmess_config_generator(domain, uuid, finalIP) + "\n")
    else:
        print("cloudflare_ip_list.txt not found, using domain directly")
        print("\n📱 VLESS WebSocket (Recommended):")
        print(vless_config_generator(domain, uuid))
        print("\n📱 VMess WebSocket (Legacy):")
        print(vmess_config_generator(domain, uuid))
else:
    print("\n📱 VLESS WebSocket (Recommended):")
    print(vless_config_generator(domain, uuid))
    print("\n📱 VMess WebSocket (Legacy):")
    print(vmess_config_generator(domain, uuid))
