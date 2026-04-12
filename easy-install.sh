#!/bin/bash

# ============================================
# Xray Proxy Setup Script
# ============================================
# Modes: VLESS+WS+CDN, VLESS+XTLS-Reality, or Both
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

# Constants
DEFAULT_SHORT_ID="abcd1234"

# Logging functions
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

echo "🚀 Xray Proxy Setup — VLESS-WS + VLESS-Reality"
echo "================================================"

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
# Get server public IP
# ============================================
get_server_ip() {
    timeout 10 curl -s --connect-timeout 5 ifconfig.me 2>/dev/null || \
    timeout 10 curl -s --connect-timeout 5 icanhazip.com 2>/dev/null || \
    echo "YOUR-SERVER-IP"
}

# ============================================
# Generate Reality x25519 keypair
# ============================================
generate_reality_keys() {
    log_info "Pulling Xray Docker image (needed for key generation)..."
    if ! docker pull ghcr.io/xtls/xray-core:latest; then
        log_warning "Docker pull failed — will try to generate keys anyway"
    fi

    log_info "Generating Reality x25519 keypair..."
    REALITY_KEYS=""
    if command -v docker &>/dev/null; then
        # Try default entrypoint first (image entrypoint = xray)
        REALITY_KEYS=$(docker run --rm ghcr.io/xtls/xray-core x25519 2>&1) || true

        # If that didn't produce key output, try explicit binary path
        if ! echo "$REALITY_KEYS" | grep -qi "PrivateKey\|Private key"; then
            log_warning "Retrying with explicit xray binary path..."
            REALITY_KEYS=$(docker run --rm --entrypoint xray ghcr.io/xtls/xray-core x25519 2>&1) || true
        fi

        # Last resort: try /usr/bin/xray
        if ! echo "$REALITY_KEYS" | grep -qi "PrivateKey\|Private key"; then
            REALITY_KEYS=$(docker run --rm --entrypoint /usr/bin/xray ghcr.io/xtls/xray-core x25519 2>&1) || true
        fi
    fi

    if echo "$REALITY_KEYS" | grep -qi "PrivateKey\|Private key"; then
        REALITY_PRIVATE_KEY=$(echo "$REALITY_KEYS" | grep -i "PrivateKey\|Private key" | awk '{print $NF}')
        REALITY_PUBLIC_KEY=$(echo "$REALITY_KEYS" | grep -i "PublicKey\|Public key" | awk '{print $NF}')
        if [ -n "$REALITY_PRIVATE_KEY" ] && [ -n "$REALITY_PUBLIC_KEY" ]; then
            log_success "Reality keypair generated successfully"
            return 0
        fi
    fi

    # Auto-generation failed — show what went wrong, then prompt user
    log_error "Could not auto-generate Reality x25519 keys!"
    if [ -n "$REALITY_KEYS" ]; then
        log_warning "Docker output was: $REALITY_KEYS"
    fi
    echo ""
    log_info "You MUST provide valid x25519 keys for Reality to work."
    log_info "Generate them with: docker run --rm ghcr.io/xtls/xray-core x25519"
    echo ""
    read -p "Enter Reality PRIVATE key: " REALITY_PRIVATE_KEY
    while [[ -z "$REALITY_PRIVATE_KEY" ]]; do
        log_error "Private key cannot be empty"
        read -p "Enter Reality PRIVATE key: " REALITY_PRIVATE_KEY
    done
    read -p "Enter Reality PUBLIC key: " REALITY_PUBLIC_KEY
    while [[ -z "$REALITY_PUBLIC_KEY" ]]; do
        log_error "Public key cannot be empty"
        read -p "Enter Reality PUBLIC key: " REALITY_PUBLIC_KEY
    done
}

# ============================================
# Prompt for Reality port with conflict check
# ============================================
prompt_reality_port() {
    local default_port="$1"
    local https_port="${2:-}"

    read -p "Enter Reality port [${default_port}]: " REALITY_PORT
    REALITY_PORT=${REALITY_PORT:-$default_port}

    # Validate numeric
    if [[ ! "$REALITY_PORT" =~ ^[0-9]+$ ]] || [ "$REALITY_PORT" -lt 1 ] || [ "$REALITY_PORT" -gt 65535 ]; then
        log_warning "Invalid port, using default ${default_port}"
        REALITY_PORT=$default_port
    fi
    # Validate no conflict with port 80
    if [ "$REALITY_PORT" = "80" ]; then
        log_warning "Port 80 is reserved for ACME. Using ${default_port} instead."
        REALITY_PORT=$default_port
    fi
    # Validate no conflict with HTTPS (if provided)
    if [ -n "$https_port" ] && [ "$REALITY_PORT" = "$https_port" ]; then
        log_warning "Reality port conflicts with HTTPS port (${https_port}). Using ${default_port} instead."
        REALITY_PORT=$default_port
    fi
}

# ============================================
# Prompt for Reality destination domain
# ============================================
prompt_reality_dest() {
    read -p "Enter Reality destination domain [www.microsoft.com:443]: " REALITY_DEST
    REALITY_DEST=${REALITY_DEST:-www.microsoft.com:443}
    REALITY_SERVER_NAME=$(echo "$REALITY_DEST" | cut -d: -f1)
    REALITY_SHORT_ID=$(head -c 4 /dev/urandom 2>/dev/null | od -A n -t x1 | tr -d ' \n' || echo "$DEFAULT_SHORT_ID")

    log_success "Reality Dest: $REALITY_DEST"
}

# ============================================
# Create .env file
# ============================================
create_env_file() {
    local mode="$1"   # ws, reality, both  -- determines which vars to write

    log_info "Creating .env configuration file..."

    cat > .env << ENVEOF
# ============================================
# Xray Proxy Configuration
# ============================================
# Generated on $(date)
# Mode: ${mode}
# ============================================

# Xray Configuration
V2RAY_UUID=${UUID}
XRAY_VERSION=latest
ENVEOF

    # WS-related vars (modes: ws, both)
    if [ "$mode" = "ws" ] || [ "$mode" = "both" ]; then
        cat >> .env << ENVEOF

# Domain Configuration
DOMAIN=${DOMAIN}
VIRTUAL_HOST=${DOMAIN}
LETSENCRYPT_HOST=${DOMAIN}
LETSENCRYPT_EMAIL=${EMAIL}

# VLESS-WS Port (internal)
VLESS_WS_PORT=1310
VLESS_WS_PATH=/

# Network Configuration
HTTP_PORT=80
HTTPS_PORT=${HTTPS_PORT}

# Container Names
NGINX_CONTAINER_NAME=nginx
V2RAY_CONTAINER_NAME=v2ray
DOCKERGEN_CONTAINER_NAME=dockergen
ACME_CONTAINER_NAME=nginx-proxy-acme

# Service Versions
NGINX_VERSION=1.22
DOCKER_GEN_VERSION=0.9
ACME_VERSION=2.2

# Nginx Proxy Settings
NGINX_PROXY_CONTAINER=nginx
NGINX_DOCKER_GEN_CONTAINER=dockergen
DEFAULT_EMAIL=${EMAIL}

# Docker-Gen Settings
TEMPLATE_PATH=/etc/docker-gen/templates/nginx.tmpl
OUTPUT_PATH=/etc/nginx/conf.d/default.conf

# ACME/SSL Settings
ACME_CA_URI=https://acme-v02.api.letsencrypt.org/directory
DEBUG=0
ENVEOF
    fi

    # Reality-related vars (modes: reality, both)
    if [ "$mode" = "reality" ] || [ "$mode" = "both" ]; then
        cat >> .env << ENVEOF

# VLESS + XTLS-Reality Configuration
REALITY_PORT=${REALITY_PORT}
VLESS_REALITY_PORT=1313
REALITY_DEST=${REALITY_DEST}
REALITY_SERVER_NAME=${REALITY_SERVER_NAME}
REALITY_PRIVATE_KEY=${REALITY_PRIVATE_KEY}
REALITY_PUBLIC_KEY=${REALITY_PUBLIC_KEY}
REALITY_SHORT_ID=${REALITY_SHORT_ID}
ENVEOF
    fi

    # Container settings for reality-only (no nginx)
    if [ "$mode" = "reality" ]; then
        cat >> .env << ENVEOF

# Container Names
V2RAY_CONTAINER_NAME=v2ray
ENVEOF
    fi

    cat >> .env << ENVEOF

# Docker Settings
RESTART_POLICY=always
COMPOSE_PROJECT_NAME=xray-proxy

# Logging Configuration
LOG_LEVEL=info
ENVEOF

    log_success ".env file created"
}

# ============================================
# Generate Xray config from template
# ============================================
generate_xray_config() {
    local template_file="$1"

    log_info "Generating Xray configuration from ${template_file}..."

    mkdir -p v2ray/config

    if [ ! -f "$template_file" ]; then
        log_error "Template not found: ${template_file}"
        exit 1
    fi

    # Export all needed variables
    export V2RAY_UUID="${UUID}"
    export VLESS_WS_PORT="${VLESS_WS_PORT:-1310}"
    export VLESS_WS_PATH="${VLESS_WS_PATH:-/}"
    export VLESS_REALITY_PORT="${VLESS_REALITY_PORT:-1313}"
    export REALITY_DEST="${REALITY_DEST:-www.microsoft.com:443}"
    export REALITY_SERVER_NAME="${REALITY_SERVER_NAME:-www.microsoft.com}"
    export REALITY_PRIVATE_KEY="${REALITY_PRIVATE_KEY}"
    export REALITY_SHORT_ID="${REALITY_SHORT_ID:-$DEFAULT_SHORT_ID}"

    if command -v envsubst &>/dev/null; then
        envsubst < "$template_file" > "./v2ray/config/config.json"
        log_success "Xray configuration generated (envsubst)"
    else
        log_warning "envsubst not found, using sed fallback"
        cp "$template_file" "./v2ray/config/config.json"
        sed -i "s|\${V2RAY_UUID}|${V2RAY_UUID}|g" "./v2ray/config/config.json"
        sed -i "s|\${VLESS_WS_PORT}|${VLESS_WS_PORT}|g" "./v2ray/config/config.json"
        sed -i "s|\${VLESS_WS_PATH}|${VLESS_WS_PATH}|g" "./v2ray/config/config.json"
        sed -i "s|\${VLESS_REALITY_PORT}|${VLESS_REALITY_PORT}|g" "./v2ray/config/config.json"
        sed -i "s|\${REALITY_DEST}|${REALITY_DEST}|g" "./v2ray/config/config.json"
        sed -i "s|\${REALITY_SERVER_NAME}|${REALITY_SERVER_NAME}|g" "./v2ray/config/config.json"
        sed -i "s|\${REALITY_PRIVATE_KEY}|${REALITY_PRIVATE_KEY}|g" "./v2ray/config/config.json"
        sed -i "s|\${REALITY_SHORT_ID}|${REALITY_SHORT_ID}|g" "./v2ray/config/config.json"
        log_success "Xray configuration generated (sed)"
    fi
}

# ============================================
# Create domain-specific vhost file
# ============================================
create_vhost_file() {
    local domain="$1"
    
    log_info "Creating domain-specific vhost configuration..."
    mkdir -p vhost
    
    if [ -f "vhost/default" ]; then
        cp "vhost/default" "vhost/${domain}"
        log_success "Created vhost/${domain}"
    fi
}

# ============================================
# Display Reality connection link
# ============================================
print_reality_link() {
    local uuid="$1"
    local server_ip="$2"
    local port="$3"
    local public_key="$4"
    local server_name="$5"
    local short_id="$6"
    local label="$7"

    if [ -z "$public_key" ] || [ -z "$server_ip" ] || [ "$server_ip" = "YOUR-SERVER-IP" ]; then
        echo ""
        log_error "Could not generate Reality connection link!"
        echo ""
        echo "   The Reality public key or server IP could not be determined."
        echo "   To get your connection link manually:"
        echo ""
        echo "   1. Check your public key:  grep REALITY_PUBLIC_KEY .env"
        echo "   2. Check your config:      docker exec v2ray cat /etc/xray/config.json"
        echo "   3. Build the link manually:"
        echo "      vless://<UUID>@<SERVER-IP>:<PORT>?type=tcp&security=reality&pbk=<PUBLIC-KEY>&fp=chrome&sni=<SNI>&sid=<SHORT-ID>&flow=xtls-rprx-vision#<NAME>"
        echo ""
        return 1
    fi

    echo "vless://${uuid}@${server_ip}:${port}?type=tcp&security=reality&pbk=${public_key}&fp=chrome&sni=${server_name}&sid=${short_id}&flow=xtls-rprx-vision#${label}"
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

# ============================================
# Setup selection
# ============================================
echo ""
echo "🎯 Choose setup mode:"
echo "1) VLESS + WebSocket + CDN       (requires domain, uses Cloudflare/CDN)"
echo "2) VLESS + XTLS-Reality          (direct connection, no domain needed)"
echo "3) Both (WS + CDN AND Reality)   (requires domain + separate Reality port)"
read -p "Enter choice (1, 2 or 3) [1]: " SETUP_CHOICE
SETUP_CHOICE=${SETUP_CHOICE:-1}

case "$SETUP_CHOICE" in
    1) MODE="ws";      COMPOSE_FILE="docker-compose.yml";         log_info "Mode: VLESS + WebSocket + CDN" ;;
    2) MODE="reality"; COMPOSE_FILE="docker-compose.reality.yml"; log_info "Mode: VLESS + XTLS-Reality (direct)" ;;
    3) MODE="both";    COMPOSE_FILE="docker-compose.modular.yml"; log_info "Mode: VLESS-WS + CDN AND VLESS-Reality (dual)" ;;
    *) log_error "Invalid choice. Exiting."; exit 1 ;;
esac

# ============================================
# UUID generation
# ============================================
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

# ============================================
# Collect inputs based on mode
# ============================================

# --- Domain & email (for ws and both modes) ---
if [ "$MODE" = "ws" ] || [ "$MODE" = "both" ]; then
    echo ""
    read -p "Enter your domain: " DOMAIN
    while [[ -z "$DOMAIN" ]]; do
        log_error "Domain cannot be empty"
        read -p "Enter your domain: " DOMAIN
    done

    read -p "Enter your email (for SSL certificates): " EMAIL
    while [[ -z "$EMAIL" ]] || [[ ! "$EMAIL" =~ ^[^@]+@[^@]+\.[^@]+$ ]]; do
        log_error "Please enter a valid email address"
        read -p "Enter your email: " EMAIL
    done

    log_success "Domain: $DOMAIN"
    log_success "Email: $EMAIL"

    echo ""
    echo "🔌 Port Configuration:"
    echo "   HTTP port 80 is REQUIRED for Let's Encrypt and cannot be changed."
    HTTPS_PORT=443
    log_success "HTTPS Port: $HTTPS_PORT"
fi

# --- Reality setup (for reality and both modes) ---
if [ "$MODE" = "reality" ] || [ "$MODE" = "both" ]; then
    echo ""
    echo "🔐 VLESS + XTLS-Reality Setup:"
    if [ "$MODE" = "both" ]; then
        echo "   Reality requires its own dedicated port (separate from HTTPS)."
    else
        echo "   Reality connects DIRECTLY to your server (no CDN, no domain needed)."
    fi
    echo ""

    # Prompt for Reality port FIRST (quick interactive step)
    if [ "$MODE" = "both" ]; then
        echo "   Reality MUST use a different port from HTTPS ($HTTPS_PORT)."
        prompt_reality_port 2083 "$HTTPS_PORT"
    else
        prompt_reality_port 443
    fi
    log_success "Reality Port: $REALITY_PORT"

    # Prompt for Reality destination
    prompt_reality_dest

    # Generate Reality keys LAST (may pull Docker image / take time)
    generate_reality_keys
fi

# ============================================
# Create .env and generate Xray config
# ============================================
create_env_file "$MODE"

# Select the right config template
case "$MODE" in
    ws)
        generate_xray_config "v2ray/config/config.no-reality.template.json"
        create_vhost_file "$DOMAIN"
        ;;
    reality)
        generate_xray_config "v2ray/config/config.reality-only.template.json"
        ;;
    both)
        generate_xray_config "v2ray/config/config.template.json"
        create_vhost_file "$DOMAIN"
        ;;
esac

# Setup logging directories
log_info "Setting up logging directories..."
if [ -f "setup-logging.sh" ]; then
    chmod +x setup-logging.sh
    ./setup-logging.sh
else
    mkdir -p logs/{nginx,v2ray,docker-gen,acme}
    chmod -R 755 logs
fi

# ============================================
# Build and start containers
# ============================================
echo ""
log_info "Starting Docker containers with: $COMPOSE_FILE"
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

# Restart nginx and dockergen to apply vhost config (WS modes only)
if [ "$MODE" = "ws" ] || [ "$MODE" = "both" ]; then
    log_info "Restarting nginx and dockergen to apply configurations..."
    $DOCKER_COMPOSE -f "$COMPOSE_FILE" restart nginx dockergen 2>/dev/null || true
    sleep 5
fi

# Show service status
echo ""
log_info "Service Status:"
$DOCKER_COMPOSE -f "$COMPOSE_FILE" ps

# ============================================
# Cloudflare instructions (WS modes)
# ============================================
if [ "$MODE" = "ws" ] || [ "$MODE" = "both" ]; then
    echo ""
    echo "🌐 Cloudflare CDN Setup:"
    echo "   1. Point your domain '$DOMAIN' to your server IP"
    echo "   2. In Cloudflare dashboard:"
    echo "      - Set SSL/TLS mode to 'Full (strict)' or 'Full'"
    echo "      - Enable 'Proxy' (orange cloud) for your domain"
    echo ""
    read -p "Press Enter when you've configured Cloudflare..."
fi

# ============================================
# Display connection links
# ============================================
echo ""
log_info "Getting server info..."
SERVER_INFO=$(get_server_info)
SERVER_IP=$(get_server_ip)

echo ""
echo "=============================================="
echo "🔗 CONNECTION LINKS — COPY THESE!"
echo "=============================================="
echo "📍 Server: $SERVER_INFO"
echo "🖥️  Server IP: $SERVER_IP"
echo ""

# --- VLESS-WS link ---
if [ "$MODE" = "ws" ] || [ "$MODE" = "both" ]; then
    CF_IP=$(get_cloudflare_ip)
    echo "🌐 Cloudflare IP: $CF_IP"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📱 VLESS WebSocket (CDN, port ${HTTPS_PORT}):"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "vless://${UUID}@${CF_IP}:${HTTPS_PORT}?type=ws&security=tls&path=%2F&host=${DOMAIN}&sni=${DOMAIN}&encryption=none#${SERVER_INFO// /-}-VLESS-WS"
    echo ""
fi

# --- VLESS-Reality link ---
if [ "$MODE" = "reality" ] || [ "$MODE" = "both" ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📱 VLESS Reality (Direct, port ${REALITY_PORT}):"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    print_reality_link "$UUID" "$SERVER_IP" "$REALITY_PORT" \
        "$REALITY_PUBLIC_KEY" "$REALITY_SERVER_NAME" "$REALITY_SHORT_ID" \
        "${SERVER_INFO// /-}-VLESS-Reality"
    echo ""
fi

echo "=============================================="
echo ""
echo "📋 Configuration saved to:"
echo "   - .env (main configuration)"
echo "   - v2ray/config/config.json (Xray config)"
if [ "$MODE" = "ws" ] || [ "$MODE" = "both" ]; then
    echo "   - vhost/${DOMAIN} (Nginx vhost)"
fi
echo ""

log_success "🎉 Setup completed successfully!"
echo ""
echo "📋 Useful commands:"
echo "   - View logs: $DOCKER_COMPOSE -f $COMPOSE_FILE logs -f"
echo "   - Restart:   $DOCKER_COMPOSE -f $COMPOSE_FILE restart"
echo "   - Stop:      $DOCKER_COMPOSE -f $COMPOSE_FILE down"
echo "   - Status:    $DOCKER_COMPOSE -f $COMPOSE_FILE ps"
echo "   - Get links: python3 vmess.py"
echo ""