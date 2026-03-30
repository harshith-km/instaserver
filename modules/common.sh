#!/bin/bash
# ============================================================
#  Common: Colors, helpers, OS detection, package wrappers
# ============================================================

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# --- Helpers ---
print_banner() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════╗"
    echo "║           instaserver                            ║"
    echo "║     Interactive EC2 Setup Script                 ║"
    echo "║     Ubuntu Server / Amazon Linux                 ║"
    echo "╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step() {
    echo -e "\n${BLUE}[STEP]${NC} ${BOLD}$1${NC}"
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

confirm() {
    local prompt="$1 [y/N]: "
    read -rp "$prompt" response
    [[ "$response" =~ ^[Yy]$ ]]
}

# --- Detect OS ---
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$ID" == "ubuntu" || "$ID" == "debian" ]]; then
            OS="ubuntu"
            PKG="apt"
        elif [[ "$ID" == "amzn" || "$ID" == "rhel" || "$ID" == "centos" || "$ID" == "fedora" ]]; then
            OS="amzn"
            PKG="yum"
        else
            print_error "Unsupported OS: $ID"
            exit 1
        fi
    else
        print_error "Cannot detect OS."
        exit 1
    fi
    print_success "Detected OS: $ID ($VERSION_ID)"
}

# --- Package Install Wrapper ---
pkg_install() {
    if [[ "$PKG" == "apt" ]]; then
        sudo apt-get install -y "$@"
    else
        sudo yum install -y "$@"
    fi
}

pkg_update() {
    print_step "Updating system packages..."
    if [[ "$PKG" == "apt" ]]; then
        sudo apt-get update -y && sudo apt-get upgrade -y
    else
        sudo yum update -y
    fi
    print_success "System packages updated."
}

# --- Install Common Tools ---
install_common() {
    print_step "Installing common utilities..."
    if [[ "$PKG" == "apt" ]]; then
        pkg_install curl wget git unzip htop net-tools software-properties-common jq tree tmux
    else
        pkg_install curl wget git unzip htop net-tools jq tree tmux
    fi
    print_success "Common utilities installed."
}

# --- Swap ---
setup_swap() {
    if [ "$(swapon --show | wc -l)" -gt 0 ]; then
        print_warn "Swap already exists. Skipping."
        return
    fi
    print_step "Setting up swap file..."
    echo -e "  Select swap size:"
    echo -e "    1) 1GB"
    echo -e "    2) 2GB (recommended for t2.micro/t3.micro)"
    echo -e "    3) 4GB"
    echo -e "    4) Custom"
    read -rp "  Choice [1-4, default=2]: " swap_choice
    swap_choice=${swap_choice:-2}

    case $swap_choice in
        1) SWAP_SIZE="1G" ;;
        2) SWAP_SIZE="2G" ;;
        3) SWAP_SIZE="4G" ;;
        4)
            read -rp "  Enter swap size (e.g., 512M, 2G): " SWAP_SIZE
            ;;
    esac

    sudo fallocate -l "$SWAP_SIZE" /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab > /dev/null

    # Optimize swappiness for server
    echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf > /dev/null
    sudo sysctl vm.swappiness=10

    print_success "$SWAP_SIZE swap configured (swappiness=10)."
}

# --- Firewall ---
setup_firewall() {
    print_step "Configuring firewall..."
    if [[ "$PKG" == "apt" ]]; then
        pkg_install ufw
        sudo ufw allow OpenSSH
        sudo ufw allow 80/tcp
        sudo ufw allow 443/tcp
        echo "y" | sudo ufw enable
        print_success "UFW firewall enabled (SSH, HTTP, HTTPS allowed)."
    else
        sudo yum install -y firewalld 2>/dev/null || true
        sudo systemctl enable firewalld 2>/dev/null || true
        sudo systemctl start firewalld 2>/dev/null || true
        sudo firewall-cmd --permanent --add-service=ssh 2>/dev/null || true
        sudo firewall-cmd --permanent --add-service=http 2>/dev/null || true
        sudo firewall-cmd --permanent --add-service=https 2>/dev/null || true
        sudo firewall-cmd --reload 2>/dev/null || true
        print_success "Firewall configured (SSH, HTTP, HTTPS allowed)."
    fi
}

# --- Timezone & Locale ---
setup_timezone() {
    echo -e "\n${CYAN}── Timezone & Locale ──${NC}"

    echo -e "  Current timezone: $(timedatectl show --property=Timezone --value 2>/dev/null || cat /etc/timezone 2>/dev/null || echo 'unknown')"

    read -rp "  Enter timezone (e.g., Asia/Kolkata, US/Eastern, UTC) [leave blank to skip]: " tz
    if [[ -n "$tz" ]]; then
        sudo timedatectl set-timezone "$tz"
        print_success "Timezone set to $tz."
    fi

    if confirm "  Set up NTP time sync?"; then
        sudo timedatectl set-ntp true
        print_success "NTP time sync enabled."
    fi
}
