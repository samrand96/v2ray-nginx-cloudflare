#!/bin/bash
set -e

echo "🐳 Installing Docker and Docker Compose..."

# Function to detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
        CODENAME=${VERSION_CODENAME:-$VERSION_ID}
    elif [ -f /etc/redhat-release ]; then
        OS="rhel"
        VERSION=$(grep -oE '[0-9]+\.[0-9]+' /etc/redhat-release | head -1)
    elif [ -f /etc/debian_version ]; then
        OS="debian"
        VERSION=$(cat /etc/debian_version)
    else
        echo "❌ Cannot detect Linux distribution"
        exit 1
    fi
    
    echo "📋 Detected: $OS $VERSION"
}

# Function to install prerequisites
install_prerequisites() {
    case $OS in
        ubuntu|debian)
            echo "📦 Installing prerequisites for Debian/Ubuntu..."
            $SUDO apt-get update
            $SUDO apt-get install -y \
                ca-certificates \
                curl \
                gnupg \
                lsb-release \
                apt-transport-https \
                software-properties-common
            ;;
        centos|rhel|rocky|almalinux)
            echo "📦 Installing prerequisites for RHEL/CentOS..."
            $SUDO yum install -y \
                ca-certificates \
                curl \
                gnupg \
                yum-utils \
                device-mapper-persistent-data \
                lvm2
            ;;
        fedora)
            echo "📦 Installing prerequisites for Fedora..."
            $SUDO dnf install -y \
                ca-certificates \
                curl \
                gnupg \
                dnf-plugins-core \
                device-mapper-persistent-data \
                lvm2
            ;;
        opensuse*|sles)
            echo "📦 Installing prerequisites for openSUSE/SLES..."
            $SUDO zypper install -y \
                ca-certificates \
                curl \
                gnupg \
                libdevmapper1_03 \
                liblvm2app2_2
            ;;
        arch|manjaro)
            echo "📦 Installing prerequisites for Arch/Manjaro..."
            $SUDO pacman -S --noconfirm \
                ca-certificates \
                curl \
                gnupg \
                lvm2 \
                device-mapper
            ;;
        alpine)
            echo "📦 Installing prerequisites for Alpine..."
            $SUDO apk add --no-cache \
                ca-certificates \
                curl \
                gnupg \
                device-mapper \
                lvm2
            ;;
        *)
            echo "⚠️  Unsupported OS: $OS"
            echo "🔄 Trying generic Docker installation..."
            ;;
    esac
}

# Function to remove old Docker versions
remove_old_docker() {
    case $OS in
        ubuntu|debian)
            $SUDO apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
            ;;
        centos|rhel|rocky|almalinux)
            $SUDO yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine 2>/dev/null || true
            ;;
        fedora)
            $SUDO dnf remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-selinux docker-engine-selinux docker-engine 2>/dev/null || true
            ;;
        opensuse*|sles)
            $SUDO zypper remove -y docker docker-runc docker-containerd 2>/dev/null || true
            ;;
        arch|manjaro)
            $SUDO pacman -Rns --noconfirm docker docker-compose 2>/dev/null || true
            ;;
        alpine)
            $SUDO apk del docker docker-compose 2>/dev/null || true
            ;;
    esac
}

# Function to install Docker
install_docker() {
    case $OS in
        ubuntu|debian)
            echo "🐳 Installing Docker for Ubuntu/Debian..."
            # Add Docker's GPG key
            $SUDO mkdir -p /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/$OS/gpg | $SUDO gpg --dearmor -o /etc/apt/keyrings/docker.gpg
            $SUDO chmod a+r /etc/apt/keyrings/docker.gpg
            
            # Add repository
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS $(lsb_release -cs) stable" | $SUDO tee /etc/apt/sources.list.d/docker.list > /dev/null
            
            # Install Docker
            $SUDO apt-get update
            $SUDO apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;
            
        centos|rhel|rocky|almalinux)
            echo "🐳 Installing Docker for RHEL/CentOS..."
            $SUDO yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            $SUDO yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;
            
        fedora)
            echo "🐳 Installing Docker for Fedora..."
            $SUDO dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
            $SUDO dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;
            
        opensuse*|sles)
            echo "🐳 Installing Docker for openSUSE/SLES..."
            $SUDO zypper addrepo https://download.docker.com/linux/sles/docker-ce.repo
            $SUDO zypper refresh
            $SUDO zypper install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin
            ;;
            
        arch|manjaro)
            echo "🐳 Installing Docker for Arch/Manjaro..."
            $SUDO pacman -S --noconfirm docker docker-compose
            ;;
            
        alpine)
            echo "🐳 Installing Docker for Alpine..."
            $SUDO apk add --no-cache docker docker-compose
            ;;
            
        *)
            echo "🐳 Using universal Docker installation script..."
            curl -fsSL https://get.docker.com | $SUDO bash
            ;;
    esac
}

# Function to install Docker Compose (standalone)
install_docker_compose() {
    # Check if Docker Compose plugin is available
    if docker compose version &>/dev/null; then
        echo "✅ Docker Compose v2 plugin is already available"
        return 0
    fi
    
    echo "📥 Installing standalone Docker Compose..."
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
    
    case $OS in
        arch|manjaro)
            # Arch has docker-compose in repos
            if ! command -v docker-compose &>/dev/null; then
                $SUDO pacman -S --noconfirm docker-compose
            fi
            ;;
        alpine)
            # Alpine has docker-compose in repos
            if ! command -v docker-compose &>/dev/null; then
                $SUDO apk add --no-cache docker-compose
            fi
            ;;
        *)
            # Download binary for other systems
            $SUDO curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
            $SUDO chmod +x /usr/local/bin/docker-compose
            $SUDO ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose 2>/dev/null || true
            ;;
    esac
}

# Function to start Docker service
start_docker() {
    case $OS in
        arch|manjaro|alpine)
            if command -v systemctl &>/dev/null; then
                $SUDO systemctl start docker
                $SUDO systemctl enable docker
            elif command -v service &>/dev/null; then
                $SUDO service docker start
            elif command -v rc-service &>/dev/null; then
                $SUDO rc-service docker start
                $SUDO rc-update add docker default
            fi
            ;;
        *)
            $SUDO systemctl start docker
            $SUDO systemctl enable docker
            ;;
    esac
}

# Main installation process
detect_os

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    SUDO=""
    echo "🔑 Running as root"
else
    SUDO="sudo"
    echo "🔑 Running with sudo"
fi

echo "🧹 Removing old Docker versions..."
remove_old_docker

echo "📦 Installing prerequisites..."
install_prerequisites

echo "🐳 Installing Docker..."
install_docker

echo "🔨 Setting up Docker Compose..."
install_docker_compose

echo "🚀 Starting Docker service..."
start_docker

# Add user to docker group (if not root)
if [ "$EUID" -ne 0 ]; then
    echo "👤 Adding user to docker group..."
    $SUDO usermod -aG docker $USER
    echo "⚠️  You need to log out and back in for group changes to take effect"
    echo "   Or run: newgrp docker"
fi

# Test Docker installation
echo "🧪 Testing Docker installation..."
if $SUDO docker run --rm hello-world &>/dev/null; then
    echo "✅ Docker installed successfully!"
else
    echo "❌ Docker installation test failed"
    exit 1
fi

# Test Docker Compose installation
echo "🧪 Testing Docker Compose installation..."
if command -v docker-compose &>/dev/null; then
    COMPOSE_VERSION=$(docker-compose --version)
    echo "✅ Docker Compose installed: $COMPOSE_VERSION"
elif docker compose version &>/dev/null; then
    COMPOSE_VERSION=$(docker compose version)
    echo "✅ Docker Compose plugin installed: $COMPOSE_VERSION"
else
    echo "❌ Docker Compose installation failed"
    exit 1
fi

echo ""
echo "🎉 Installation completed successfully!"
echo "📋 Summary:"
echo "   - OS: $OS $VERSION"
echo "   - Docker Engine: $(docker --version)"
if command -v docker-compose &>/dev/null; then
    echo "   - Docker Compose: $(docker-compose --version)"
elif docker compose version &>/dev/null; then
    echo "   - Docker Compose: $(docker compose version)"
fi
echo ""
if [ "$EUID" -ne 0 ]; then
    echo "⚠️  Remember to log out and back in, or run 'newgrp docker' to use Docker without sudo"
fi