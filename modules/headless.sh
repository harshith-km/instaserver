#!/bin/bash
# ============================================================
#  Headless: Non-interactive setup via config file
#  Enables running via EC2 user-data or automation
# ============================================================

run_headless() {
    local config_file="$1"

    if [[ -z "$config_file" ]]; then
        print_error "Usage: run_headless <config-file>"
        print_error "  Example: run_headless ./instaserver.conf"
        return 1
    fi

    if [[ ! -f "$config_file" ]]; then
        print_error "Config file not found: $config_file"
        return 1
    fi

    print_step "Running instaserver in headless mode..."
    echo -e "  Config file: ${BOLD}$config_file${NC}"

    headless_parse_config "$config_file" || return 1
    headless_run
}

headless_parse_config() {
    local config_file="$1"

    print_step "Parsing config file..."

    # Validate the config file - check for dangerous content
    if grep -qE '^\s*[^#A-Z_]' "$config_file" 2>/dev/null; then
        # Allow empty lines
        local bad_lines
        bad_lines=$(grep -nE '^\s*[^#A-Z_]' "$config_file" | grep -vE '^\d+:\s*$')
        if [[ -n "$bad_lines" ]]; then
            print_warn "Config file contains unexpected lines:"
            echo "$bad_lines"
        fi
    fi

    # Set defaults before sourcing
    UPDATE_SYSTEM="${UPDATE_SYSTEM:-no}"
    SETUP_SWAP="${SETUP_SWAP:-no}"
    SWAP_SIZE="${SWAP_SIZE:-2G}"
    INSTALL_NODE="${INSTALL_NODE:-no}"
    NODE_VERSION="${NODE_VERSION:-20}"
    INSTALL_PM2="${INSTALL_PM2:-no}"
    INSTALL_NGINX="${INSTALL_NGINX:-no}"
    INSTALL_DOCKER="${INSTALL_DOCKER:-no}"
    INSTALL_PYTHON="${INSTALL_PYTHON:-no}"
    INSTALL_CERTBOT="${INSTALL_CERTBOT:-no}"
    SETUP_FIREWALL="${SETUP_FIREWALL:-no}"
    SETUP_FAIL2BAN="${SETUP_FAIL2BAN:-no}"
    DISABLE_ROOT_SSH="${DISABLE_ROOT_SSH:-no}"
    DISABLE_PASSWORD_AUTH="${DISABLE_PASSWORD_AUTH:-no}"
    SSH_PORT="${SSH_PORT:-22}"
    INSTALL_POSTGRESQL="${INSTALL_POSTGRESQL:-no}"
    INSTALL_MYSQL="${INSTALL_MYSQL:-no}"
    INSTALL_REDIS="${INSTALL_REDIS:-no}"
    INSTALL_MONGODB="${INSTALL_MONGODB:-no}"
    APP_PORT="${APP_PORT:-3000}"
    APP_DOMAIN="${APP_DOMAIN:-}"
    TIMEZONE="${TIMEZONE:-UTC}"

    # Source the config (overrides defaults)
    source "$config_file"

    print_success "Config loaded."
    echo -e "  UPDATE_SYSTEM=${BOLD}$UPDATE_SYSTEM${NC}  INSTALL_NODE=${BOLD}$INSTALL_NODE${NC}  INSTALL_NGINX=${BOLD}$INSTALL_NGINX${NC}"
    echo -e "  INSTALL_DOCKER=${BOLD}$INSTALL_DOCKER${NC}  SETUP_FIREWALL=${BOLD}$SETUP_FIREWALL${NC}  SETUP_FAIL2BAN=${BOLD}$SETUP_FAIL2BAN${NC}"
}

headless_run() {
    local failed=0

    # Timezone
    if [[ -n "$TIMEZONE" && "$TIMEZONE" != "UTC" ]]; then
        print_step "Setting timezone to $TIMEZONE..."
        sudo timedatectl set-timezone "$TIMEZONE" 2>/dev/null || true
        print_success "Timezone set to $TIMEZONE."
    fi

    # System update
    if [[ "$UPDATE_SYSTEM" == "yes" ]]; then
        pkg_update || { print_error "System update failed."; failed=1; }
    fi

    # Swap
    if [[ "$SETUP_SWAP" == "yes" ]]; then
        if [ "$(swapon --show | wc -l)" -gt 0 ]; then
            print_warn "Swap already exists. Skipping."
        else
            print_step "Setting up ${SWAP_SIZE} swap..."
            sudo fallocate -l "$SWAP_SIZE" /swapfile
            sudo chmod 600 /swapfile
            sudo mkswap /swapfile
            sudo swapon /swapfile
            echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab > /dev/null
            echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf > /dev/null
            sudo sysctl vm.swappiness=10
            print_success "${SWAP_SIZE} swap configured."
        fi
    fi

    # Node.js
    if [[ "$INSTALL_NODE" == "yes" ]]; then
        print_step "Installing Node.js ${NODE_VERSION}..."
        if [[ "$PKG" == "apt" ]]; then
            curl -fsSL "https://deb.nodesource.com/setup_${NODE_VERSION}.x" | sudo -E bash -
            sudo apt-get install -y nodejs
        else
            curl -fsSL "https://rpm.nodesource.com/setup_${NODE_VERSION}.x" | sudo bash -
            sudo yum install -y nodejs
        fi
        sudo npm install -g npm@latest 2>/dev/null || true
        print_success "Node.js $(node -v 2>/dev/null || echo "${NODE_VERSION}") installed."
    fi

    # PM2
    if [[ "$INSTALL_PM2" == "yes" ]]; then
        print_step "Installing PM2..."
        sudo npm install -g pm2
        pm2 startup systemd -u "$USER" --hp "$HOME" 2>/dev/null | tail -1 | sudo bash - 2>/dev/null || true
        print_success "PM2 installed."
    fi

    # Nginx
    if [[ "$INSTALL_NGINX" == "yes" ]]; then
        install_nginx

        # Configure reverse proxy if we have an app port
        if [[ -n "$APP_PORT" ]]; then
            configure_nginx_backend "$APP_PORT" "$APP_DOMAIN"
        fi
    fi

    # Docker
    if [[ "$INSTALL_DOCKER" == "yes" ]]; then
        install_docker
    fi

    # Python
    if [[ "$INSTALL_PYTHON" == "yes" ]]; then
        install_python
    fi

    # Certbot + SSL
    if [[ "$INSTALL_CERTBOT" == "yes" ]]; then
        install_certbot
    fi

    # Databases
    if [[ "$INSTALL_POSTGRESQL" == "yes" ]]; then
        install_postgresql
    fi

    if [[ "$INSTALL_MYSQL" == "yes" ]]; then
        install_mysql
    fi

    if [[ "$INSTALL_MONGODB" == "yes" ]]; then
        install_mongodb
    fi

    if [[ "$INSTALL_REDIS" == "yes" ]]; then
        install_redis
    fi

    # Firewall
    if [[ "$SETUP_FIREWALL" == "yes" ]]; then
        setup_firewall
    fi

    # Fail2Ban
    if [[ "$SETUP_FAIL2BAN" == "yes" ]]; then
        ssh_install_fail2ban
    fi

    # SSH hardening
    local sshd_changed=0
    local sshd_config="/etc/ssh/sshd_config"

    if [[ "$SSH_PORT" != "22" ]]; then
        print_step "Changing SSH port to $SSH_PORT..."
        sudo sed -i "s/^#\?Port .*/Port $SSH_PORT/" "$sshd_config"
        if [[ "$PKG" == "apt" ]]; then
            sudo ufw allow "$SSH_PORT/tcp" 2>/dev/null || true
        else
            sudo firewall-cmd --permanent --add-port="${SSH_PORT}/tcp" 2>/dev/null || true
            sudo firewall-cmd --reload 2>/dev/null || true
        fi
        print_success "SSH port changed to $SSH_PORT."
        sshd_changed=1
    fi

    if [[ "$DISABLE_ROOT_SSH" == "yes" ]]; then
        print_step "Disabling root SSH login..."
        sudo sed -i "s/^#\?PermitRootLogin .*/PermitRootLogin no/" "$sshd_config"
        print_success "Root login disabled."
        sshd_changed=1
    fi

    if [[ "$DISABLE_PASSWORD_AUTH" == "yes" ]]; then
        print_step "Disabling SSH password authentication..."
        sudo sed -i "s/^#\?PasswordAuthentication .*/PasswordAuthentication no/" "$sshd_config"
        sudo sed -i "s/^#\?ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/" "$sshd_config"
        print_success "Password authentication disabled."
        sshd_changed=1
    fi

    if [[ "$sshd_changed" -eq 1 ]]; then
        sudo systemctl restart sshd 2>/dev/null || true
        print_success "SSH service restarted."
    fi

    # Summary
    echo -e "\n${GREEN}══════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Headless setup complete!${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════${NC}"

    if [[ "$failed" -eq 1 ]]; then
        print_warn "Some steps encountered errors. Review the output above."
    fi
}

generate_config() {
    echo -e "\n${CYAN}── Generate Headless Config ──${NC}"
    echo -e "  This will create a reusable config file for non-interactive setup.\n"

    local config_file="./instaserver.conf"

    # System
    local update_system="yes"
    if ! confirm "  Update system packages on setup?"; then
        update_system="no"
    fi

    local setup_swap="yes"
    local swap_size="2G"
    if confirm "  Set up swap file?"; then
        read -rp "  Swap size [default: 2G]: " swap_size
        swap_size=${swap_size:-2G}
    else
        setup_swap="no"
    fi

    # Timezone
    read -rp "  Timezone [default: UTC]: " timezone
    timezone=${timezone:-UTC}

    # Node.js
    local install_node="no"
    local node_version="20"
    local install_pm2="no"
    if confirm "  Install Node.js?"; then
        install_node="yes"
        read -rp "  Node.js version (18, 20, 22) [default: 20]: " node_version
        node_version=${node_version:-20}
        if confirm "  Install PM2 (process manager)?"; then
            install_pm2="yes"
        fi
    fi

    # Nginx
    local install_nginx="no"
    if confirm "  Install Nginx?"; then
        install_nginx="yes"
    fi

    # Docker
    local install_docker="no"
    if confirm "  Install Docker?"; then
        install_docker="yes"
    fi

    # Python
    local install_python="no"
    if confirm "  Install Python?"; then
        install_python="yes"
    fi

    # Certbot
    local install_certbot="no"
    if confirm "  Install Certbot (SSL)?"; then
        install_certbot="yes"
    fi

    # Databases
    local install_postgresql="no"
    local install_mysql="no"
    local install_mongodb="no"
    local install_redis="no"

    if confirm "  Install PostgreSQL?"; then install_postgresql="yes"; fi
    if confirm "  Install MySQL/MariaDB?"; then install_mysql="yes"; fi
    if confirm "  Install MongoDB?"; then install_mongodb="yes"; fi
    if confirm "  Install Redis?"; then install_redis="yes"; fi

    # Security
    local setup_firewall="yes"
    if ! confirm "  Set up firewall (UFW/firewalld)?"; then
        setup_firewall="no"
    fi

    local setup_fail2ban="yes"
    if ! confirm "  Install Fail2Ban?"; then
        setup_fail2ban="no"
    fi

    local disable_root_ssh="yes"
    if ! confirm "  Disable root SSH login?"; then
        disable_root_ssh="no"
    fi

    local disable_password_auth="no"
    if confirm "  Disable SSH password authentication (key-only)?"; then
        disable_password_auth="yes"
    fi

    local ssh_port="22"
    read -rp "  SSH port [default: 22]: " ssh_port
    ssh_port=${ssh_port:-22}

    # App config
    local app_port="3000"
    local app_domain=""
    read -rp "  Application port [default: 3000]: " app_port
    app_port=${app_port:-3000}
    read -rp "  Domain name (leave blank for none): " app_domain

    # Write the config file
    cat > "$config_file" <<CONF
# instaserver headless config
# Generated on $(date '+%Y-%m-%d %H:%M:%S')
# Usage: run with --headless flag or source in user-data

# System
UPDATE_SYSTEM=${update_system}
SETUP_SWAP=${setup_swap}
SWAP_SIZE=${swap_size}
TIMEZONE=${timezone}

# Runtime
INSTALL_NODE=${install_node}
NODE_VERSION=${node_version}
INSTALL_PM2=${install_pm2}
INSTALL_PYTHON=${install_python}
INSTALL_DOCKER=${install_docker}

# Web Server & SSL
INSTALL_NGINX=${install_nginx}
INSTALL_CERTBOT=${install_certbot}

# Databases
INSTALL_POSTGRESQL=${install_postgresql}
INSTALL_MYSQL=${install_mysql}
INSTALL_MONGODB=${install_mongodb}
INSTALL_REDIS=${install_redis}

# Security
SETUP_FIREWALL=${setup_firewall}
SETUP_FAIL2BAN=${setup_fail2ban}
DISABLE_ROOT_SSH=${disable_root_ssh}
DISABLE_PASSWORD_AUTH=${disable_password_auth}
SSH_PORT=${ssh_port}

# Application
APP_PORT=${app_port}
APP_DOMAIN=${app_domain}
CONF

    print_success "Config saved to $config_file"
    echo -e "\n  ${BOLD}To use this config:${NC}"
    echo -e "    ./setup.sh --headless $config_file"
    echo -e "    or in EC2 user-data:"
    echo -e "    ${CYAN}#!/bin/bash"
    echo -e "    curl -sL <your-url>/setup.sh -o /tmp/setup.sh"
    echo -e "    curl -sL <your-url>/instaserver.conf -o /tmp/instaserver.conf"
    echo -e "    chmod +x /tmp/setup.sh"
    echo -e "    /tmp/setup.sh --headless /tmp/instaserver.conf${NC}"
}
