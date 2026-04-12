#!/usr/bin/python3

"""
Legacy setup script for the original VLESS-WS docker-compose.yml.
For the full setup experience, use easy-install.sh instead.
"""

import uuid
import json
import yaml
from pathlib import Path

v2rayConfigPath = Path(__file__).parent / "v2ray" / "config" / "config.json"
dockerComposePath = Path(__file__).parent / "docker-compose.yml"

with open(str(v2rayConfigPath), "r", encoding="utf-8") as f:
    config = json.load(f)
with open(str(dockerComposePath), "r") as f:
    dockerComposeObject = yaml.safe_load(f)

# INPUT: UUID
defaultUUID = config["inbounds"][0]["settings"]["clients"][0]["id"]

if defaultUUID == "<UPSTREAM-UUID>":
    message = "UUID: (Leave empty to generate a random one)\n"
else:
    message = f"UUID: (Leave empty to use `{defaultUUID}`)\n"

upstreamUUID = input(message)
if upstreamUUID == "":
    if defaultUUID == "<UPSTREAM-UUID>":
        upstreamUUID = str(uuid.uuid4())
    else:
        upstreamUUID = defaultUUID

# INPUT: Domain
domain = input("Enter your domain (e.g. example.com):\n")

# INPUT: SSL
sslEnable = False
isSSLEnable = input("Enable SSL (Let's Encrypt)? (yes/no) [no]:\n")
email = ""
if isSSLEnable == "yes":
    sslEnable = True
    email = input("Enter your email for Let's Encrypt:\n")

# SAVE
config["inbounds"][0]["settings"]["clients"][0]["id"] = upstreamUUID

env_list = dockerComposeObject["services"]["v2ray"]["environment"]
for i, env_var in enumerate(env_list):
    if env_var.startswith("VIRTUAL_HOST="):
        env_list[i] = f"VIRTUAL_HOST={domain}"
    elif env_var.startswith("LETSENCRYPT_HOST="):
        env_list[i] = f"LETSENCRYPT_HOST={domain if sslEnable else ''}"
    elif env_var.startswith("LETSENCRYPT_EMAIL="):
        env_list[i] = f"LETSENCRYPT_EMAIL={email if sslEnable else ''}"

acme_env_list = dockerComposeObject["services"]["nginx-proxy-acme"]["environment"]
for i, env_var in enumerate(acme_env_list):
    if env_var.startswith("DEFAULT_EMAIL="):
        acme_env_list[i] = f"DEFAULT_EMAIL={email if sslEnable else ''}"

with open(str(v2rayConfigPath), "w", encoding="utf-8") as f:
    json.dump(config, f, indent=2)
with open(str(dockerComposePath), "w", encoding="utf-8") as f:
    yaml.dump(dockerComposeObject, f, default_flow_style=False)

print(f"\n---------")
print(f"UUID: {upstreamUUID}")
print(f"Domain: {domain}")
if sslEnable:
    print(f"SSL: enabled")
    print(f"Email: {email}")
print(f"---------\n")
print("Done!")
print("- Run: docker compose up -d")
print("- Run: python3 vmess.py to get your VLESS connection links\n")