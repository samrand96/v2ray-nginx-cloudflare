#!/bin/bash

# ============================================
# V2Ray + Nginx + Cloudflare Easy Setup Script
# ============================================
# Supports: Ubuntu, Debian, CentOS, RHEL, Fedora, Arch, Alpine, openSUSE
# All configuration is stored in a single .env file
# ============================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

echo "🚀 V2Ray + Nginx + Cloudflare Easy Setup Script"
echo "=============================================="

# ============================================
# OS Detection Function (supports all major distros)
# ============================================
detect_os() {
    OS=""
    VER=""
    CODENAME=""
    PKG_MANAGER=""
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            OS=$ID
            VER=$VERSION_ID
            CODENAME=${VERSION_CODENAME:-$VER}
        elif [ -f /etc/redhat-release ]; then
            OS="centos"
            VER=$(grep -oE '[0-9]+' /etc/redhat-release | head -1)
        elif [ -f /etc/debian_version ]; then
            OS="debian"
            VER=$(cat /etc/debian_version)
        elif [ -f /etc/alpine-release ]; then
            OS="alpine"
            VER=$(cat /etc/alpine-release)
        else
            log_error "Cannot detect Linux distribution"
            exit 1
        fi
        
        # Determine package manager
        case $OS in
            ubuntu|debian|linuxmint|pop|elementary|zorin)
                PKG_MANAGER="apt"
                ;;
            centos|rhel|rocky|almalinux|ol|fedora|amzn)
                if command -v dnf &>/dev/null; then
                    PKG_MANAGER="dnf"
                else
                    PKG_MANAGER="yum"
                fi
                ;;
            arch|manjaro|endeavouros|garuda)
                PKG_MANAGER="pacman"
                ;;
            alpine)
                PKG_MANAGER="apk"
                ;;
            opensuse*|sles)
                PKG_MANAGER="zypper"
                ;;
            *)
                log_warning "Unknown distribution: $OS. Attempting generic installation."
                PKG_MANAGER="unknown"
                ;;
        esac
    else
        log_error "This script supports Linux distributions only"
        exit 1
    fi
}

# ============================================
# Install required packages for each distro
# ============================================
install_requirements() {
    log_info "Installing required packages..."
    
    local SUDO=""
    [ "$EUID" -ne 0 ] && SUDO="sudo"
    
    case $PKG_MANAGER in
        apt)
            $SUDO apt-get update -qq
            $SUDO apt-get install -y -qq curl wget git jq gettext-base uuid-runtime
            ;;
        dnf|yum)
            $SUDO $PKG_MANAGER install -y curl wget git jq gettext util-linux
            ;;
        pacman)
            $SUDO pacman -Sy --noconfirm curl wget git jq gettext util-linux
            ;;
        apk)
            $SUDO apk add --no-cache curl wget git jq gettext util-linux bash
            ;;
        zypper)
            $SUDO zypper install -y curl wget git jq gettext-runtime util-linux
            ;;
        *)
            log_warning "Please ensure curl, wget, git, jq, envsubst and uuidgen are installed"
            ;;
    esac
    
    log_success "Required packages installed"
}

# ============================================
# Install Docker (multi-distro support)
# ============================================
install_docker() {
    log_info "Installing Docker..."
    
    local SUDO=""
    [ "$EUID" -ne 0 ] && SUDO="sudo"
    
    # Check if install-docker.sh exists locally
    if [ -f "./install-docker.sh" ]; then
        chmod +x ./install-docker.sh
        ./install-docker.sh
        return
    fi
    
    # Use official Docker installation script
    log_info "Downloading Docker installation script..."
    curl -fsSL https://get.docker.com | $SUDO bash
    
    # Install Docker Compose based on package manager
    case $PKG_MANAGER in
        apt)
            $SUDO apt-get install -y -qq docker-compose-plugin 2>/dev/null || true
            ;;
        dnf|yum)
            $SUDO $PKG_MANAGER install -y docker-compose-plugin 2>/dev/null || true
            ;;
        pacman)
            $SUDO pacman -S --noconfirm docker-compose 2>/dev/null || true
            ;;
        apk)
            $SUDO apk add --no-cache docker-compose 2>/dev/null || true
            ;;
        zypper)
            $SUDO zypper install -y docker-compose 2>/dev/null || true
            ;;
    esac
    
    # Start and enable Docker service
    if command -v systemctl &>/dev/null; then
        $SUDO systemctl start docker 2>/dev/null || true
        $SUDO systemctl enable docker 2>/dev/null || true
    elif command -v rc-service &>/dev/null; then
        $SUDO rc-service docker start 2>/dev/null || true
        $SUDO rc-update add docker default 2>/dev/null || true
    fi
    
    # Add user to docker group
    if [ "$EUID" -ne 0 ]; then
        $SUDO usermod -aG docker $USER 2>/dev/null || true
        log_warning "Please log out and back in for Docker group changes to take effect"
    fi
    
    log_success "Docker installed successfully"
}

# ============================================
# Generate UUID (cross-platform)
# ============================================
generate_uuid() {
    if command -v uuidgen &>/dev/null; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    elif [ -f /proc/sys/kernel/random/uuid ]; then
        cat /proc/sys/kernel/random/uuid
    else
        # Fallback: generate pseudo-UUID
        printf '%04x%04x-%04x-%04x-%04x-%04x%04x%04x\n' \
            $RANDOM $RANDOM $RANDOM \
            $(($RANDOM & 0x0fff | 0x4000)) \
            $(($RANDOM & 0x3fff | 0x8000)) \
            $RANDOM $RANDOM $RANDOM
    fi
}

# ============================================
# Get random Cloudflare IP
# ============================================
get_cloudflare_ip() {
    if [ -f "cloudflare_ip_list.txt" ]; then
        local cidr=$(shuf -n 1 cloudflare_ip_list.txt 2>/dev/null || head -n 1 cloudflare_ip_list.txt)
        local network=$(echo $cidr | cut -d'/' -f1)
        local prefix=$(echo $cidr | cut -d'/' -f2)
        local base_ip=$(echo $network | cut -d'.' -f1-3)
        
        case "$prefix" in
            24) echo "$base_ip.$((RANDOM % 254 + 1))" ;;
            23) echo "$base_ip.$((RANDOM % 510 + 1))" ;;
            22) echo "$base_ip.$((RANDOM % 1022 + 1))" ;;
            *) echo "$base_ip.$(($(echo $network | cut -d'.' -f4) + 1))" ;;
        esac
    else
        echo "104.16.1.1"
    fi
}

# ============================================
# Get server location info
# ============================================
get_server_info() {
    local country_code=""
    local flag_emoji="🌍"
    local country_name="Unknown"
    
    if command -v curl &>/dev/null; then
        local geo_info=""
        geo_info=$(timeout 10 curl -s --connect-timeout 5 "http://ip-api.com/json/" 2>/dev/null) || \
        geo_info=$(timeout 10 curl -s --connect-timeout 5 "https://ipapi.co/json/" 2>/dev/null) || \
        geo_info=""
        
        if [ -n "$geo_info" ] && echo "$geo_info" | grep -q "country"; then
            country_code=$(echo "$geo_info" | grep -o '"countryCode":"[^"]*"' | cut -d'"' -f4 | head -1)
            country_name=$(echo "$geo_info" | grep -o '"country":"[^"]*"' | cut -d'"' -f4 | head -1)
        fi
    fi
    
    case "$country_code" in
        US) flag_emoji="🇺🇸" ;; CA) flag_emoji="🇨🇦" ;; GB|UK) flag_emoji="🇬🇧" ;;
        DE) flag_emoji="🇩🇪" ;; FR) flag_emoji="🇫🇷" ;; NL) flag_emoji="🇳🇱" ;;
        SG) flag_emoji="🇸🇬" ;; JP) flag_emoji="🇯🇵" ;; KR) flag_emoji="🇰🇷" ;;
        AU) flag_emoji="🇦🇺" ;; BR) flag_emoji="🇧🇷" ;; IN) flag_emoji="🇮🇳" ;;
        RU) flag_emoji="🇷🇺" ;; CN) flag_emoji="🇨🇳" ;; HK) flag_emoji="🇭🇰" ;;
        TW) flag_emoji="🇹🇼" ;; IT) flag_emoji="🇮🇹" ;; ES) flag_emoji="🇪🇸" ;;
        SE) flag_emoji="🇸🇪" ;; CH) flag_emoji="🇨🇭" ;; NO) flag_emoji="🇳🇴" ;;
        FI) flag_emoji="🇫🇮" ;; IR) flag_emoji="🇮🇷" ;; TR) flag_emoji="🇹🇷" ;;
    esac
    
    echo "$flag_emoji $country_name"
}

# ============================================
# Create .env file from user input
# ============================================
create_env_file() {
    local domain="$1"
    local email="$2"
    local uuid="$3"
    
    log_info "Creating centralized .env configuration file..."
    
    cat > .env << EOF
# ============================================
# V2Ray + Nginx + Cloudflare Configuration
# ============================================
# Generated on $(date)
# All services read from this single file
# ============================================

# Domain Configuration
DOMAIN=${domain}
VIRTUAL_HOST=${domain}
LETSENCRYPT_HOST=${domain}
LETSENCRYPT_EMAIL=${email}

# V2Ray Configuration
V2RAY_UUID=${uuid}
V2RAY_VERSION=v4.45.2

# Protocol Ports
VLESS_WS_PORT=1310
VLESS_GRPC_PORT=1311
VMESS_WS_PORT=1312

# Protocol Paths
VLESS_WS_PATH=/vless-ws
VLESS_GRPC_SERVICE=vless-grpc
VMESS_WS_PATH=/vmess-ws

# Protocol Enablement
VLESS_WS_ENABLED=true
VLESS_GRPC_ENABLED=true
VMESS_WS_ENABLED=true

# Container Names
NGINX_CONTAINER_NAME=nginx
V2RAY_CONTAINER_NAME=v2ray
DOCKERGEN_CONTAINER_NAME=dockergen
ACME_CONTAINER_NAME=nginx-proxy-acme

# Service Versions
NGINX_VERSION=1.22
DOCKER_GEN_VERSION=0.9
ACME_VERSION=2.2

# Docker Settings
RESTART_POLICY=always
COMPOSE_PROJECT_NAME=v2ray-proxy

# V2Ray Advanced Settings
V2RAY_VMESS_AEAD_FORCED=false
V2RAY_SECURITY=auto
V2RAY_ALTERID=0

# Network Configuration
HTTP_PORT=80
HTTPS_PORT=443

# Nginx Proxy Settings
NGINX_PROXY_CONTAINER=nginx
NGINX_DOCKER_GEN_CONTAINER=dockergen
DEFAULT_EMAIL=${email}

# Docker-Gen Settings
TEMPLATE_PATH=/etc/docker-gen/templates/nginx.tmpl
OUTPUT_PATH=/etc/nginx/conf.d/default.conf

# ACME/SSL Settings
ACME_CA_URI=https://acme-v02.api.letsencrypt.org/directory
DEBUG=0

# Logging Configuration
LOG_LEVEL=info
ENABLE_ACCESS_LOG=true
ENABLE_ERROR_LOG=true
EOF
    
    log_success ".env file created successfully"
}

# ============================================
# Generate V2Ray config from template
# ============================================
generate_v2ray_config() {
    local uuid="$1"
    
    log_info "Generating V2Ray configuration..."
    
    # Source .env file to get variables
    if [ -f ".env" ]; then
        set -a
        source .env
        set +a
    fi
    
    # Set defaults if not in .env
    export V2RAY_UUID="${uuid}"
    export VLESS_WS_PORT="${VLESS_WS_PORT:-1310}"
    export VLESS_WS_PATH="${VLESS_WS_PATH:-/vless-ws}"
    export VLESS_GRPC_PORT="${VLESS_GRPC_PORT:-1311}"
    export VLESS_GRPC_SERVICE="${VLESS_GRPC_SERVICE:-vless-grpc}"
    export VMESS_WS_PORT="${VMESS_WS_PORT:-1312}"
    export VMESS_WS_PATH="${VMESS_WS_PATH:-/vmess-ws}"
    
    # Use template if available
    if [ -f "./v2ray/config/config.template.json" ]; then
        if command -v envsubst &>/dev/null; then
            envsubst < "./v2ray/config/config.template.json" > "./v2ray/config/config.json"
            log_success "V2Ray configuration generated from template"
        else
            log_warning "envsubst not found, using sed fallback"
            cp "./v2ray/config/config.template.json" "./v2ray/config/config.json"
            sed -i "s|\${V2RAY_UUID}|${V2RAY_UUID}|g" "./v2ray/config/config.json"
            sed -i "s|\${VLESS_WS_PORT}|${VLESS_WS_PORT}|g" "./v2ray/config/config.json"
            sed -i "s|\${VLESS_WS_PATH}|${VLESS_WS_PATH}|g" "./v2ray/config/config.json"
            sed -i "s|\${VLESS_GRPC_PORT}|${VLESS_GRPC_PORT}|g" "./v2ray/config/config.json"
            sed -i "s|\${VLESS_GRPC_SERVICE}|${VLESS_GRPC_SERVICE}|g" "./v2ray/config/config.json"
            sed -i "s|\${VMESS_WS_PORT}|${VMESS_WS_PORT}|g" "./v2ray/config/config.json"
            sed -i "s|\${VMESS_WS_PATH}|${VMESS_WS_PATH}|g" "./v2ray/config/config.json"
            log_success "V2Ray configuration generated using sed"
        fi
    else
        log_error "V2Ray config template not found!"
        exit 1
    fi
}

# ============================================
# Create domain-specific vhost file
# ============================================
create_vhost_file() {
    local domain="$1"
    
    log_info "Creating domain-specific vhost configuration..."
    
    # Ensure vhost directory exists
    mkdir -p vhost
    
    # Copy default to domain-specific file
    if [ -f "vhost/default" ]; then
        cp "vhost/default" "vhost/${domain}"
        log_success "Created vhost/${domain}"
    fi
}

# ============================================
# MAIN SCRIPT
# ============================================

# Detect OS
detect_os
log_success "Detected OS: $OS $VER (Package Manager: $PKG_MANAGER)"

# Install requirements
install_requirements

# Check Docker installation
if ! command -v docker &>/dev/null; then
    read -p "Docker is not installed. Install Docker? (Y/n): " INSTALL_DOCKER
    if [[ "${INSTALL_DOCKER:-Y}" =~ ^[Yy]$ ]]; then
        install_docker
        if ! command -v docker &>/dev/null; then
            log_error "Docker installation failed. Please install Docker manually."
            exit 1
        fi
    else
        log_error "Docker is required. Exiting."
        exit 1
    fi
fi

# Check Docker Compose
DOCKER_COMPOSE=""
if command -v docker-compose &>/dev/null; then
    DOCKER_COMPOSE="docker-compose"
elif docker compose version &>/dev/null 2>&1; then
    DOCKER_COMPOSE="docker compose"
else
    log_error "Docker Compose not found. Please install Docker Compose."
    exit 1
fi

log_success "Using: $DOCKER_COMPOSE"

# Clone repository if needed
REPO_NAME="v2ray-nginx-cloudflare"
REPO_URL="https://github.com/samrand96/v2ray-nginx-cloudflare.git"

if [ -d "$REPO_NAME/.git" ]; then
    log_info "Repository exists. Updating..."
    cd "$REPO_NAME"
    git pull origin main 2>/dev/null || log_warning "Could not update repository"
elif [ ! -f "docker-compose.modular.yml" ]; then
    log_info "Cloning repository..."
    if git clone "$REPO_URL"; then
        log_success "Repository cloned successfully"
        cd "$REPO_NAME"
    else
        log_error "Failed to clone repository"
        exit 1
    fi
fi

# Setup selection
echo ""
echo "🎯 Choose setup type:"
echo "1) Original setup (VMess only)"
echo "2) Modular setup (Multi-protocol: VLESS+VMess) [Recommended]"
read -p "Enter choice (1 or 2) [2]: " SETUP_CHOICE
SETUP_CHOICE=${SETUP_CHOICE:-2}

if [ "$SETUP_CHOICE" = "1" ]; then
    COMPOSE_FILE="docker-compose.yml"
    log_info "Using original VMess-only setup"
else
    COMPOSE_FILE="docker-compose.modular.yml"
    log_info "Using modular multi-protocol setup"
fi

# UUID generation
echo ""
read -p "Use a custom UUID? (y/N): " CUSTOM_UUID
if [[ "${CUSTOM_UUID}" =~ ^[Yy]$ ]]; then
    read -p "Enter your UUID: " UUID
    while [[ ! "$UUID" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; do
        log_error "Invalid UUID format"
        read -p "Enter your UUID: " UUID
    done
else
    UUID=$(generate_uuid)
fi

log_success "UUID: $UUID"

# Domain and email input
echo ""
read -p "Enter your domain: " DOMAIN
while [[ -z "$DOMAIN" ]]; do
    log_error "Domain cannot be empty"
    read -p "Enter your domain: " DOMAIN
done

read -p "Enter your email: " EMAIL
while [[ -z "$EMAIL" ]] || [[ ! "$EMAIL" =~ ^[^@]+@[^@]+\.[^@]+$ ]]; do
    log_error "Please enter a valid email address"
    read -p "Enter your email: " EMAIL
done

log_success "Domain: $DOMAIN"
log_success "Email: $EMAIL"

# Create centralized .env file
create_env_file "$DOMAIN" "$EMAIL" "$UUID"

# Generate V2Ray config
if [ "$SETUP_CHOICE" = "2" ]; then
    generate_v2ray_config "$UUID"
    create_vhost_file "$DOMAIN"
else
    # Original setup - update config.json directly
    if [ -f "./v2ray/config/config.json" ]; then
        sed -i "s#<UPSTREAM-UUID>#$UUID#g" "./v2ray/config/config.json"
        log_success "Updated UUID in config.json"
    fi
fi

# Setup logging directories
log_info "Setting up logging directories..."
if [ -f "setup-logging.sh" ]; then
    chmod +x setup-logging.sh
    ./setup-logging.sh
else
    mkdir -p logs/{nginx,v2ray,docker-gen,acme}
    chmod -R 755 logs
fi

# Build and start containers
echo ""
log_info "Starting Docker containers..."
if $DOCKER_COMPOSE -f "$COMPOSE_FILE" up -d; then
    log_success "Docker containers started successfully!"
else
    log_error "Failed to start containers"
    $DOCKER_COMPOSE -f "$COMPOSE_FILE" logs
    exit 1
fi

# Wait for services
log_info "Waiting for services to initialize..."
sleep 10

# Restart nginx and dockergen to apply vhost config
log_info "Restarting nginx and dockergen to apply configurations..."
$DOCKER_COMPOSE -f "$COMPOSE_FILE" restart nginx dockergen 2>/dev/null || true
sleep 5

# Show service status
echo ""
log_info "Service Status:"
$DOCKER_COMPOSE -f "$COMPOSE_FILE" ps

# Cloudflare instructions
echo ""
echo "🌐 Cloudflare CDN Setup:"
echo "   1. Point your domain '$DOMAIN' to your server IP"
echo "   2. In Cloudflare dashboard:"
echo "      - Set SSL/TLS mode to 'Full (strict)' or 'Full'"
echo "      - Enable 'Proxy' (orange cloud) for your domain"
echo "      - Optional: Enable 'Always Use HTTPS'"
echo ""

read -p "Press Enter when you've configured Cloudflare..."

# Generate client configurations
if [ "$SETUP_CHOICE" = "2" ]; then
    echo ""
    log_info "Getting server location and Cloudflare IP..."
    SERVER_INFO=$(get_server_info)
    CF_IP=$(get_cloudflare_ip)
    
    echo ""
    echo "=============================================="
    echo "🔗 CONNECTION LINKS (using Cloudflare CDN)"
    echo "=============================================="
    echo "📍 Server: $SERVER_INFO"
    echo "🌐 Cloudflare IP: $CF_IP"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📱 VLESS WebSocket (Recommended):"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "vless://${UUID}@${CF_IP}:443?type=ws&security=tls&path=%2Fvless-ws&host=${DOMAIN}&sni=${DOMAIN}#${SERVER_INFO// /-}-VLESS-WS"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📱 VLESS gRPC:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "vless://${UUID}@${CF_IP}:443?type=grpc&security=tls&serviceName=vless-grpc&host=${DOMAIN}&sni=${DOMAIN}#${SERVER_INFO// /-}-VLESS-gRPC"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📱 VMess WebSocket:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    VMESS_CONFIG=$(echo -n "{\"v\":\"2\",\"ps\":\"${SERVER_INFO// /-}-VMess-WS\",\"add\":\"${CF_IP}\",\"port\":\"443\",\"type\":\"none\",\"id\":\"${UUID}\",\"aid\":\"0\",\"net\":\"ws\",\"path\":\"/vmess-ws\",\"host\":\"${DOMAIN}\",\"tls\":\"tls\",\"sni\":\"${DOMAIN}\"}" | base64 -w 0 2>/dev/null || base64)
    echo "vmess://${VMESS_CONFIG}"
    echo ""
    echo "=============================================="
    echo ""
    echo "📋 Your configuration has been saved to:"
    echo "   - .env (main configuration)"
    echo "   - v2ray/config/config.json (V2Ray config)"
    echo "   - vhost/${DOMAIN} (Nginx vhost)"
    echo ""
else
    # Original VMess config
    if command -v python3 &>/dev/null && [ -f "vmess.py" ]; then
        echo ""
        log_info "Generating VMess client configuration..."
        chmod +x vmess.py
        ./vmess.py
    else
        echo ""
        echo "📱 Manual VMess configuration:"
        echo "   Address: $DOMAIN"
        echo "   Port: 443"
        echo "   UUID: $UUID"
        echo "   Security: auto"
        echo "   Network: ws"
        echo "   Path: /"
        echo "   TLS: tls"
    fi
fi

echo ""
log_success "🎉 Setup completed successfully!"
echo ""
echo "📋 Useful commands:"
echo "   - View logs: $DOCKER_COMPOSE -f $COMPOSE_FILE logs -f"
echo "   - Restart services: $DOCKER_COMPOSE -f $COMPOSE_FILE restart"
echo "   - Stop services: $DOCKER_COMPOSE -f $COMPOSE_FILE down"
echo "   - View status: $DOCKER_COMPOSE -f $COMPOSE_FILE ps"
echo ""
