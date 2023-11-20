#!/bin/bash

# Check if Docker is installed
if ! [ -x "$(command -v docker)" ]; then
  read -p "Docker is not installed. Do you want to install Docker? (Y/n): " INSTALL_DOCKER
  if [ ${INSTALL_DOCKER:-Y} == "Y" ]; then
    sudo su -c "bash <(wget -qO- https://get.docker.com)" root
    apt install -y docker-compose
  else
    echo "Exiting setup. Docker installation required."
    exit 1
  fi
fi

# Continue with the rest of the script...


# Clone the git repository
git clone https://github.com/samrandhaji/v2ray-nginx-cloudflare.git
cd v2ray-nginx-cloudflare

# Generate random UUID
read -p "Do you want to use a custom UUID? (Y/n): " CUSTOM_UUID
if [ ${CUSTOM_UUID:-Y} == "Y" ]; then
  read -p "Enter your custom UUID: " UUID
else
  UUID=$(cat /proc/sys/kernel/random/uuid)
fi


# Update the <UPSTREAM-UUID> field in config.json
sed -i "s#<UPSTREAM-UUID>#$UUID#g" ./v2ray/config/config.json

# Prompt for domain and email
read -p "Enter your domain: " DOMAIN
read -p "Enter your email: " EMAIL

# Replace placeholders in docker-compose.yml
sed -i "s#YOUR_DOMAIN#$DOMAIN#g" ./docker-compose.yml
sed -i "s#YOUR_EMAIL#$EMAIL#g" ./docker-compose.yml

# Compose the Docker setup
docker-compose up -d

# Prompt for CDN usage
read -p "Now go and adjust CDN Settings: In your CDN, activate the proxy option for the record to enhance the delivery capabilities. When you finished press Enter " USE_CDN
if [ ${USE_CDN:-Y} == "Y" ]; then
  # Turn on proxy mode in A record inside the CDN
  # Run the vmess.py file
  chmod +x vmess.py
  ./vmess.py
fi
