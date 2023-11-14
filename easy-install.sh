#!/bin/bash

# Check if Docker is installed
if ! [ -x "$(command -v docker)" ]; then
  read -p "Docker is not installed. Would you like to install Docker? (yes/no): " INSTALL_DOCKER
  if [ $INSTALL_DOCKER == "yes" ]; then
    sudo su -c "bash <(wget -qO- https://get.docker.com)" root
    apt install -y docker-compose
  else
    echo "Exiting setup. Docker installation required."
    exit 1
  fi
fi


# Clone the git repository
git clone https://github.com/samrandhaji/v2ray-nginx-cdn.git
cd v2ray-nginx-cdn

# Generate random UUID
UUID=$(cat /proc/sys/kernel/random/uuid)

# Update the <UPSTREAM-UUID> field in config.json
sed -i "s#<UPSTREAM-UUID>#$UUID#g" v2ray/config/config.json

# Prompt for domain and email
read -p "Enter your domain: " DOMAIN
read -p "Enter your email: " EMAIL

# Replace placeholders in docker-compose.yml
sed -i "s#YOUR_DOMAIN#$DOMAIN#g" docker-compose.yml
sed -i "s#YOUR_EMAIL#$EMAIL#g" docker-compose.yml

# Compose the Docker setup
docker-compose up -d

# Prompt for CDN usage
read -p "Do you want to use CDN? (yes/no): " USE_CDN
if [ $USE_CDN == "yes" ]; then
  # Turn on proxy mode in A record inside the CDN
  # Run the vmess.py file
  ./vmess.py
fi
