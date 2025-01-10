#!/bin/bash

# Check if Docker is installed
if ! command -v docker &>/dev/null; then
  read -p "Docker is not installed. Do you want to install Docker? (Y/n): " INSTALL_DOCKER
  if [[ "${INSTALL_DOCKER:-Y}" =~ ^[Yy]$ ]]; then
    curl -fsSL https://get.docker.com | sudo bash
    if ! command -v docker &>/dev/null; then
      echo "Docker installation failed. Exiting."
      exit 1
    fi
    # Install Docker Compose
    sudo apt update && sudo apt install -y docker-compose
    if ! command -v docker-compose &>/dev/null; then
      echo "Docker Compose installation failed. Exiting."
      exit 1
    fi
  else
    echo "Exiting setup. Docker installation required."
    exit 1
  fi
fi

# Clone the Git repository only if it doesn't already exist
REPO_NAME="v2ray-nginx-cloudflare"
REPO_URL="https://github.com/samrand96/v2ray-nginx-cloudflare.git"

if [ -d "$REPO_NAME" ]; then
  echo "Repository $REPO_NAME already exists. Skipping cloning."
else
  if ! git clone "$REPO_URL"; then
    echo "Failed to clone the repository. Exiting."
    exit 1
  fi
fi

# Navigate to the repository directory
cd "$REPO_NAME" || { echo "Failed to navigate to the repository directory. Exiting."; exit 1; }

# Generate random UUID
read -p "Do you want to use a custom UUID? (Y/n): " CUSTOM_UUID
if [[ "${CUSTOM_UUID:-Y}" =~ ^[Yy]$ ]]; then
  read -p "Enter your custom UUID: " UUID
  UUID=${UUID:-$(cat /proc/sys/kernel/random/uuid)}
else
  UUID=$(cat /proc/sys/kernel/random/uuid)
fi

# Update the <UPSTREAM-UUID> field in config.json
if ! sed -i "s#<UPSTREAM-UUID>#$UUID#g" ./v2ray/config/config.json; then
  echo "Failed to update UUID in config.json. Exiting."
  exit 1
fi

# Prompt for domain and email
read -p "Enter your domain: " DOMAIN
read -p "Enter your email: " EMAIL

# Replace placeholders in docker-compose.yml
if ! sed -i "s#YOUR_DOMAIN#$DOMAIN#g" ./docker-compose.yml || ! sed -i "s#YOUR_EMAIL#$EMAIL#g" ./docker-compose.yml; then
  echo "Failed to update placeholders in docker-compose.yml. Exiting."
  exit 1
fi

# Compose the Docker setup
if ! docker-compose up -d; then
  echo "Failed to start Docker containers. Exiting."
  exit 1
fi

# Prompt for CDN usage
read -p "Now go and adjust CDN settings. Activate the proxy option in your CDN for the record to enhance delivery capabilities. Press Enter when finished." USE_CDN
if [[ "${USE_CDN:-Y}" =~ ^[Yy]$ ]]; then
  chmod +x vmess.py
  if ! ./vmess.py; then
    echo "Failed to execute vmess.py. Exiting."
    exit 1
  fi
fi

echo "Setup completed successfully."