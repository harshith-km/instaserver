#!/bin/bash
# ============================================================
#  Export / Import Server Configuration
# ============================================================

setup_export() {
    echo -e "\n${CYAN}── Export / Import Configuration ──${NC}"

    echo -e "\n  ${BOLD}Options:${NC}"
    echo -e "    1) Export current server config"
    echo -e "    2) Import config from file"
    echo -e "    3) Back to main menu"
    read -rp "  Choice [1-3]: " export_choice

    case $export_choice in
        1) export_config ;;
        2) import_config ;;
        3) return ;;
        *) print_error "Invalid choice."; return ;;
    esac
}

# ------------------------------------------------------------
#  Export Configuration
# ------------------------------------------------------------

export_config() {
    echo -e "\n${CYAN}── Export Server Configuration ──${NC}"
    print_step "Gathering system information..."

    local date_stamp
    date_stamp=$(date '+%Y%m%d')
    local export_file="$HOME/server-config-export-${date_stamp}.txt"
    local conf_file="$HOME/instaserver.conf"

    # Start the export file
    {
        echo "============================================================"
        echo "  instaserver - Server Configuration Export"
        echo "  Generated: $(date '+%Y-%m-%d %H:%M:%S %Z')"
        echo "  Hostname:  $(hostname)"
        echo "============================================================"
        echo ""

        # --- OS Info ---
        echo "── OS Information ──"
        if [[ -f /etc/os-release ]]; then
            . /etc/os-release
            echo "  Distribution: $PRETTY_NAME"
            echo "  ID:           $ID"
            echo "  Version:      $VERSION_ID"
        fi
        echo "  Kernel:       $(uname -r)"
        echo "  Architecture: $(uname -m)"
        echo "  Uptime:       $(uptime -p 2>/dev/null || uptime)"
        echo ""

        # --- Installed Packages / Versions ---
        echo "── Installed Software ──"

        if command -v node &>/dev/null; then
            echo "  Node.js:      $(node --version 2>/dev/null)"
        else
            echo "  Node.js:      (not installed)"
        fi

        if command -v npm &>/dev/null; then
            echo "  npm:          $(npm --version 2>/dev/null)"
        fi

        if command -v python3 &>/dev/null; then
            echo "  Python3:      $(python3 --version 2>/dev/null)"
        elif command -v python &>/dev/null; then
            echo "  Python:       $(python --version 2>/dev/null)"
        else
            echo "  Python:       (not installed)"
        fi

        if command -v docker &>/dev/null; then
            echo "  Docker:       $(docker --version 2>/dev/null)"
        else
            echo "  Docker:       (not installed)"
        fi

        if command -v docker-compose &>/dev/null || command -v "docker compose" &>/dev/null; then
            local dc_ver
            dc_ver=$(docker compose version 2>/dev/null || docker-compose --version 2>/dev/null)
            echo "  Compose:      $dc_ver"
        fi

        if command -v nginx &>/dev/null; then
            echo "  Nginx:        $(nginx -v 2>&1)"
        else
            echo "  Nginx:        (not installed)"
        fi

        if command -v apache2 &>/dev/null || command -v httpd &>/dev/null; then
            local apache_ver
            apache_ver=$(apache2 -v 2>/dev/null | head -1 || httpd -v 2>/dev/null | head -1)
            echo "  Apache:       $apache_ver"
        fi

        if command -v psql &>/dev/null; then
            echo "  PostgreSQL:   $(psql --version 2>/dev/null)"
        else
            echo "  PostgreSQL:   (not installed)"
        fi

        if command -v mysql &>/dev/null; then
            echo "  MySQL:        $(mysql --version 2>/dev/null)"
        else
            echo "  MySQL:        (not installed)"
        fi

        if command -v mongod &>/dev/null; then
            echo "  MongoDB:      $(mongod --version 2>/dev/null | head -1)"
        else
            echo "  MongoDB:      (not installed)"
        fi

        if command -v redis-server &>/dev/null; then
            echo "  Redis:        $(redis-server --version 2>/dev/null)"
        else
            echo "  Redis:        (not installed)"
        fi

        if command -v git &>/dev/null; then
            echo "  Git:          $(git --version 2>/dev/null)"
        fi

        if command -v certbot &>/dev/null; then
            echo "  Certbot:      $(certbot --version 2>/dev/null 2>&1)"
        fi

        if command -v pm2 &>/dev/null; then
            echo "  PM2:          $(pm2 --version 2>/dev/null)"
        fi

        if command -v aws &>/dev/null; then
            echo "  AWS CLI:      $(aws --version 2>/dev/null)"
        fi
        echo ""

        # --- Running Services ---
        echo "── Running Services ──"
        if command -v systemctl &>/dev/null; then
            systemctl list-units --type=service --state=running --no-pager --no-legend 2>/dev/null | while IFS= read -r line; do
                echo "  $line"
            done
        else
            echo "  (systemctl not available)"
        fi
        echo ""

        # --- Open Ports ---
        echo "── Open Ports ──"
        if command -v ss &>/dev/null; then
            ss -tlnp 2>/dev/null | while IFS= read -r line; do
                echo "  $line"
            done
        elif command -v netstat &>/dev/null; then
            netstat -tlnp 2>/dev/null | while IFS= read -r line; do
                echo "  $line"
            done
        else
            echo "  (ss/netstat not available)"
        fi
        echo ""

        # --- Nginx Sites ---
        echo "── Nginx Sites Configured ──"
        if [[ -d /etc/nginx/sites-enabled ]]; then
            local sites
            sites=$(ls /etc/nginx/sites-enabled/ 2>/dev/null)
            if [[ -n "$sites" ]]; then
                for site in /etc/nginx/sites-enabled/*; do
                    local site_name
                    site_name=$(basename "$site")
                    echo "  [$site_name]"
                    grep -E '^\s*(server_name|listen|root|proxy_pass|location)\s' "$site" 2>/dev/null | while IFS= read -r line; do
                        echo "    $line"
                    done
                    echo ""
                done
            else
                echo "  (no sites enabled)"
            fi
        elif [[ -d /etc/nginx/conf.d ]]; then
            local confs
            confs=$(ls /etc/nginx/conf.d/*.conf 2>/dev/null)
            if [[ -n "$confs" ]]; then
                for conf in /etc/nginx/conf.d/*.conf; do
                    echo "  [$(basename "$conf")]"
                    grep -E '^\s*(server_name|listen|root|proxy_pass|location)\s' "$conf" 2>/dev/null | while IFS= read -r line; do
                        echo "    $line"
                    done
                    echo ""
                done
            else
                echo "  (no conf.d configs)"
            fi
        else
            echo "  (nginx config directories not found)"
        fi
        echo ""

        # --- Firewall Rules ---
        echo "── Firewall Rules ──"
        if command -v ufw &>/dev/null; then
            echo "  [ufw]"
            sudo ufw status verbose 2>/dev/null | while IFS= read -r line; do
                echo "    $line"
            done
        elif command -v firewall-cmd &>/dev/null; then
            echo "  [firewalld]"
            sudo firewall-cmd --list-all 2>/dev/null | while IFS= read -r line; do
                echo "    $line"
            done
        elif command -v iptables &>/dev/null; then
            echo "  [iptables]"
            sudo iptables -L -n --line-numbers 2>/dev/null | while IFS= read -r line; do
                echo "    $line"
            done
        else
            echo "  (no firewall tool found)"
        fi
        echo ""

        # --- Cron Jobs ---
        echo "── Cron Jobs ──"
        echo "  [User: $USER]"
        local user_crons
        user_crons=$(crontab -l 2>/dev/null)
        if [[ -n "$user_crons" ]]; then
            echo "$user_crons" | while IFS= read -r line; do
                echo "    $line"
            done
        else
            echo "    (none)"
        fi
        echo "  [Root]"
        local root_crons
        root_crons=$(sudo crontab -l 2>/dev/null)
        if [[ -n "$root_crons" ]]; then
            echo "$root_crons" | while IFS= read -r line; do
                echo "    $line"
            done
        else
            echo "    (none)"
        fi
        echo ""

        # --- SSH Config Summary ---
        echo "── SSH Configuration ──"
        if [[ -f /etc/ssh/sshd_config ]]; then
            echo "  Port:                  $(grep -E '^Port\s' /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' || echo '22 (default)')"
            echo "  PermitRootLogin:       $(grep -E '^PermitRootLogin\s' /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' || echo 'not set')"
            echo "  PasswordAuthentication:$(grep -E '^PasswordAuthentication\s' /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' || echo ' not set')"
            echo "  PubkeyAuthentication:  $(grep -E '^PubkeyAuthentication\s' /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}' || echo 'not set')"
            echo "  AuthorizedKeys:        $(wc -l < ~/.ssh/authorized_keys 2>/dev/null || echo '0') key(s) in ~/.ssh/authorized_keys"
        else
            echo "  (sshd_config not found)"
        fi
        echo ""

        # --- .bashrc Customizations ---
        echo "── .bashrc Custom Additions ──"
        if [[ -f ~/.bashrc ]]; then
            # Show lines added by instaserver (marked with comments) or custom aliases/functions
            local custom_lines
            custom_lines=$(grep -n -E '^\s*(alias |export |function |# instaserver)' ~/.bashrc 2>/dev/null)
            if [[ -n "$custom_lines" ]]; then
                echo "$custom_lines" | while IFS= read -r line; do
                    echo "    $line"
                done
            else
                echo "    (no custom aliases/exports detected)"
            fi
        else
            echo "    (~/.bashrc not found)"
        fi
        echo ""

        echo "============================================================"
        echo "  End of export"
        echo "============================================================"

    } > "$export_file"

    print_success "Server configuration exported to: $export_file"

    # --- Generate headless config file ---
    print_step "Generating headless config file..."

    {
        echo "# ============================================================"
        echo "# instaserver headless configuration"
        echo "# Generated: $(date '+%Y-%m-%d %H:%M:%S %Z')"
        echo "# Source: $(hostname)"
        echo "#"
        echo "# Use this file to recreate the server setup:"
        echo "#   bash setup.sh --headless instaserver.conf"
        echo "# ============================================================"
        echo ""

        # Detect what's installed and build config flags
        echo "# --- System ---"
        echo "UPDATE_PACKAGES=yes"

        local swap_size
        swap_size=$(swapon --show=SIZE --noheadings 2>/dev/null | head -1 | tr -d '[:space:]')
        if [[ -n "$swap_size" ]]; then
            echo "SETUP_SWAP=yes"
            echo "SWAP_SIZE=${swap_size}"
        else
            echo "SETUP_SWAP=no"
        fi
        echo ""

        echo "# --- Software ---"
        if command -v node &>/dev/null; then
            local node_major
            node_major=$(node --version 2>/dev/null | grep -oP '(?<=v)\d+')
            echo "INSTALL_NODE=yes"
            echo "NODE_VERSION=${node_major}"
        else
            echo "INSTALL_NODE=no"
        fi

        if command -v python3 &>/dev/null; then
            echo "INSTALL_PYTHON=yes"
        else
            echo "INSTALL_PYTHON=no"
        fi

        if command -v docker &>/dev/null; then
            echo "INSTALL_DOCKER=yes"
        else
            echo "INSTALL_DOCKER=no"
        fi

        if command -v nginx &>/dev/null; then
            echo "INSTALL_NGINX=yes"
        else
            echo "INSTALL_NGINX=no"
        fi

        if command -v certbot &>/dev/null; then
            echo "INSTALL_CERTBOT=yes"
        else
            echo "INSTALL_CERTBOT=no"
        fi

        if command -v pm2 &>/dev/null; then
            echo "INSTALL_PM2=yes"
        else
            echo "INSTALL_PM2=no"
        fi
        echo ""

        echo "# --- Databases ---"
        if command -v psql &>/dev/null; then
            echo "INSTALL_POSTGRESQL=yes"
        else
            echo "INSTALL_POSTGRESQL=no"
        fi

        if command -v mysql &>/dev/null; then
            echo "INSTALL_MYSQL=yes"
        else
            echo "INSTALL_MYSQL=no"
        fi

        if command -v mongod &>/dev/null; then
            echo "INSTALL_MONGODB=yes"
        else
            echo "INSTALL_MONGODB=no"
        fi

        if command -v redis-server &>/dev/null; then
            echo "INSTALL_REDIS=yes"
        else
            echo "INSTALL_REDIS=no"
        fi
        echo ""

        echo "# --- SSH ---"
        if [[ -f /etc/ssh/sshd_config ]]; then
            local ssh_port
            ssh_port=$(grep -E '^Port\s' /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
            echo "SSH_PORT=${ssh_port:-22}"

            local root_login
            root_login=$(grep -E '^PermitRootLogin\s' /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
            echo "SSH_PERMIT_ROOT=${root_login:-yes}"

            local pass_auth
            pass_auth=$(grep -E '^PasswordAuthentication\s' /etc/ssh/sshd_config 2>/dev/null | awk '{print $2}')
            echo "SSH_PASSWORD_AUTH=${pass_auth:-yes}"
        fi
        echo ""

        echo "# --- Firewall ---"
        if command -v ufw &>/dev/null; then
            local ufw_status
            ufw_status=$(sudo ufw status 2>/dev/null | head -1)
            if echo "$ufw_status" | grep -qi "active"; then
                echo "SETUP_FIREWALL=yes"
                echo "FIREWALL_TOOL=ufw"
                # List allowed ports
                local allowed_ports
                allowed_ports=$(sudo ufw status 2>/dev/null | grep -E 'ALLOW' | awk '{print $1}' | sort -u | tr '\n' ',' | sed 's/,$//')
                echo "FIREWALL_ALLOW_PORTS=${allowed_ports}"
            else
                echo "SETUP_FIREWALL=no"
            fi
        elif command -v firewall-cmd &>/dev/null; then
            echo "SETUP_FIREWALL=yes"
            echo "FIREWALL_TOOL=firewalld"
        else
            echo "SETUP_FIREWALL=no"
        fi
        echo ""

        echo "# --- Monitoring ---"
        if command -v htop &>/dev/null; then
            echo "INSTALL_HTOP=yes"
        fi
        if command -v fail2ban-client &>/dev/null; then
            echo "INSTALL_FAIL2BAN=yes"
        else
            echo "INSTALL_FAIL2BAN=no"
        fi
        echo ""

        echo "# --- Git ---"
        local git_name git_email
        git_name=$(git config --global user.name 2>/dev/null)
        git_email=$(git config --global user.email 2>/dev/null)
        if [[ -n "$git_name" ]]; then
            echo "GIT_USER_NAME=\"${git_name}\""
        fi
        if [[ -n "$git_email" ]]; then
            echo "GIT_USER_EMAIL=\"${git_email}\""
        fi
        echo ""

        echo "# --- Timezone ---"
        local tz
        tz=$(timedatectl show -p Timezone --value 2>/dev/null || cat /etc/timezone 2>/dev/null)
        if [[ -n "$tz" ]]; then
            echo "TIMEZONE=\"${tz}\""
        fi

    } > "$conf_file"

    print_success "Headless config file generated: $conf_file"
    echo -e "\n  ${BOLD}Files created:${NC}"
    echo -e "    ${CYAN}$export_file${NC}  (human-readable report)"
    echo -e "    ${CYAN}$conf_file${NC}              (headless config for re-deployment)"
    echo ""
}

# ------------------------------------------------------------
#  Import Configuration
# ------------------------------------------------------------

import_config() {
    echo -e "\n${CYAN}── Import Configuration ──${NC}"

    read -rp "  Path to config file [default: ~/instaserver.conf]: " config_path
    config_path="${config_path:-$HOME/instaserver.conf}"

    if [[ ! -f "$config_path" ]]; then
        print_error "Config file not found: $config_path"
        return 1
    fi

    # Validate it looks like an instaserver config
    if ! grep -q 'instaserver' "$config_path" 2>/dev/null; then
        print_warn "This file does not appear to be an instaserver config."
        if ! confirm "  Continue anyway?"; then
            return 0
        fi
    fi

    echo -e "\n  ${BOLD}Config file:${NC} $config_path"
    echo -e "\n  ${BOLD}Summary of settings:${NC}"

    # Show key settings from the config
    grep -E '^[A-Z_]+=.' "$config_path" 2>/dev/null | grep -v '^#' | while IFS= read -r line; do
        echo -e "    ${GREEN}>${NC} $line"
    done

    echo ""
    if ! confirm "  Apply this configuration?"; then
        print_warn "Import cancelled."
        return 0
    fi

    # Check if run_headless function exists (from headless module)
    if declare -f run_headless &>/dev/null; then
        print_step "Delegating to headless installer..."
        run_headless "$config_path"
    else
        # Fallback: source the config and apply manually
        print_step "Loading configuration..."
        source "$config_path"

        print_step "Applying configuration..."

        # System updates
        if [[ "$UPDATE_PACKAGES" == "yes" ]]; then
            if declare -f pkg_update &>/dev/null; then
                pkg_update
            fi
        fi

        # Swap
        if [[ "$SETUP_SWAP" == "yes" ]] && declare -f setup_swap &>/dev/null; then
            setup_swap
        fi

        # Node.js
        if [[ "$INSTALL_NODE" == "yes" ]]; then
            if command -v node &>/dev/null; then
                print_success "Node.js already installed: $(node --version)"
            elif declare -f install_node &>/dev/null; then
                install_node
            else
                print_warn "install_node function not available. Skipping Node.js."
            fi
        fi

        # Docker
        if [[ "$INSTALL_DOCKER" == "yes" ]]; then
            if command -v docker &>/dev/null; then
                print_success "Docker already installed."
            elif declare -f install_docker &>/dev/null; then
                install_docker
            else
                print_warn "install_docker function not available. Skipping Docker."
            fi
        fi

        # Nginx
        if [[ "$INSTALL_NGINX" == "yes" ]]; then
            if command -v nginx &>/dev/null; then
                print_success "Nginx already installed."
            else
                print_step "Installing Nginx..."
                pkg_install nginx 2>/dev/null
            fi
        fi

        # Databases
        if [[ "$INSTALL_POSTGRESQL" == "yes" ]] && ! command -v psql &>/dev/null; then
            if declare -f install_postgresql &>/dev/null; then
                install_postgresql
            else
                print_warn "install_postgresql function not available. Skipping."
            fi
        fi

        if [[ "$INSTALL_MYSQL" == "yes" ]] && ! command -v mysql &>/dev/null; then
            if declare -f install_mysql &>/dev/null; then
                install_mysql
            else
                print_warn "install_mysql function not available. Skipping."
            fi
        fi

        if [[ "$INSTALL_REDIS" == "yes" ]] && ! command -v redis-server &>/dev/null; then
            if declare -f install_redis &>/dev/null; then
                install_redis
            else
                print_warn "install_redis function not available. Skipping."
            fi
        fi

        # Certbot
        if [[ "$INSTALL_CERTBOT" == "yes" ]] && ! command -v certbot &>/dev/null; then
            if declare -f install_certbot &>/dev/null; then
                install_certbot
            else
                print_warn "install_certbot function not available. Skipping."
            fi
        fi

        # Fail2ban
        if [[ "$INSTALL_FAIL2BAN" == "yes" ]] && ! command -v fail2ban-client &>/dev/null; then
            print_step "Installing fail2ban..."
            pkg_install fail2ban 2>/dev/null
        fi

        # Git config
        if [[ -n "$GIT_USER_NAME" ]]; then
            git config --global user.name "$GIT_USER_NAME"
        fi
        if [[ -n "$GIT_USER_EMAIL" ]]; then
            git config --global user.email "$GIT_USER_EMAIL"
        fi

        # Timezone
        if [[ -n "$TIMEZONE" ]]; then
            print_step "Setting timezone to $TIMEZONE..."
            sudo timedatectl set-timezone "$TIMEZONE" 2>/dev/null
        fi

        # Firewall
        if [[ "$SETUP_FIREWALL" == "yes" ]]; then
            if declare -f setup_firewall &>/dev/null; then
                setup_firewall
            else
                print_warn "setup_firewall function not available. Skipping."
            fi
        fi

        print_success "Configuration import complete."
    fi

    echo ""
}
