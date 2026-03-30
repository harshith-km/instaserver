#!/bin/bash
# ============================================================
#  Multisite: Manage multiple Nginx virtual hosts / sites
# ============================================================

# --- Determine Nginx config directories based on OS ---
_nginx_available_dir() {
    if [[ "$PKG" == "apt" ]]; then
        echo "/etc/nginx/sites-available"
    else
        echo "/etc/nginx/conf.d"
    fi
}

_nginx_enabled_dir() {
    if [[ "$PKG" == "apt" ]]; then
        echo "/etc/nginx/sites-enabled"
    else
        echo "/etc/nginx/conf.d"
    fi
}

# --- Helper: enable a site ---
_site_enable() {
    local name="$1"
    if [[ "$PKG" == "apt" ]]; then
        sudo ln -sf "/etc/nginx/sites-available/${name}" "/etc/nginx/sites-enabled/${name}"
    else
        sudo cp "/etc/nginx/conf.d/${name}.available" "/etc/nginx/conf.d/${name}.conf"
    fi
}

# --- Helper: disable a site ---
_site_disable() {
    local name="$1"
    if [[ "$PKG" == "apt" ]]; then
        sudo rm -f "/etc/nginx/sites-enabled/${name}"
    else
        sudo rm -f "/etc/nginx/conf.d/${name}.conf"
    fi
}

# --- Helper: check if site is enabled ---
_site_is_enabled() {
    local name="$1"
    if [[ "$PKG" == "apt" ]]; then
        [[ -L "/etc/nginx/sites-enabled/${name}" ]]
    else
        [[ -f "/etc/nginx/conf.d/${name}.conf" ]]
    fi
}

# --- Helper: list site names ---
_site_list_names() {
    if [[ "$PKG" == "apt" ]]; then
        ls /etc/nginx/sites-available/ 2>/dev/null | grep -v '^default$'
    else
        ls /etc/nginx/conf.d/ 2>/dev/null | sed -n 's/\.available$//p'
    fi
}

# --- Helper: get config file path (the "source" config) ---
_site_config_path() {
    local name="$1"
    if [[ "$PKG" == "apt" ]]; then
        echo "/etc/nginx/sites-available/${name}"
    else
        echo "/etc/nginx/conf.d/${name}.available"
    fi
}

# ============================================================
#  1) Main menu
# ============================================================

setup_multisite() {
    echo -e "\n${CYAN}── Multisite Manager ──${NC}"

    while true; do
        echo ""
        echo -e "  ${BOLD}Nginx Virtual Host Manager${NC}"
        echo -e "    1) Add a new site (reverse proxy)"
        echo -e "    2) Add a new site (static files)"
        echo -e "    3) List all configured sites"
        echo -e "    4) Enable / disable a site"
        echo -e "    5) Remove a site"
        echo -e "    6) Test Nginx config & reload"
        echo -e "    7) Back to main menu"
        read -rp "  Choice [1-7]: " ms_choice

        case $ms_choice in
            1) multisite_add_proxy ;;
            2) multisite_add_static ;;
            3) multisite_list ;;
            4) multisite_toggle ;;
            5) multisite_remove ;;
            6) multisite_test ;;
            7) return ;;
            *) print_error "Invalid choice." ;;
        esac
    done
}

# ============================================================
#  2) Add reverse proxy site
# ============================================================

multisite_add_proxy() {
    echo -e "\n${CYAN}── Add Reverse Proxy Site ──${NC}"

    read -rp "  Domain name (e.g., api.example.com): " domain
    if [[ -z "$domain" ]]; then
        print_error "Domain name is required."
        return
    fi

    local config_path
    config_path=$(_site_config_path "$domain")
    if [[ -f "$config_path" ]]; then
        print_warn "Site config for '$domain' already exists."
        if ! confirm "  Overwrite existing config?"; then
            return
        fi
    fi

    read -rp "  Backend port (e.g., 3000): " port
    if [[ -z "$port" ]]; then
        print_error "Backend port is required."
        return
    fi

    local ws_support="n"
    read -rp "  Enable WebSocket support? [y/N]: " ws_support
    ws_support=${ws_support:-n}

    local rate_limit="n"
    read -rp "  Enable rate limiting? [y/N]: " rate_limit
    rate_limit=${rate_limit:-n}

    print_step "Creating Nginx reverse proxy config for $domain..."

    # Build the config
    local rate_limit_zone=""
    local rate_limit_directive=""
    if [[ "$rate_limit" =~ ^[Yy]$ ]]; then
        rate_limit_zone="limit_req_zone \$binary_remote_addr zone=${domain//\./_}_limit:10m rate=10r/s;"
        rate_limit_directive="        limit_req zone=${domain//\./_}_limit burst=20 nodelay;"
    fi

    local ws_headers=""
    if [[ "$ws_support" =~ ^[Yy]$ ]]; then
        ws_headers='        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";'
    else
        ws_headers='        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection '\''keep-alive'\'';'
    fi

    local config_content
    config_content=$(cat <<NGINXEOF
${rate_limit_zone:+${rate_limit_zone}
}server {
    listen 80;
    server_name ${domain};

    location / {
        proxy_pass http://127.0.0.1:${port};
        proxy_http_version 1.1;
${ws_headers}
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_read_timeout 86400s;
        proxy_send_timeout 86400s;
${rate_limit_directive:+${rate_limit_directive}
}    }
}
NGINXEOF
)

    echo "$config_content" | sudo tee "$config_path" > /dev/null
    print_success "Config written to $config_path"

    # Enable the site
    _site_enable "$domain"
    print_success "Site '$domain' enabled."

    # Test and reload
    if sudo nginx -t 2>&1; then
        sudo systemctl reload nginx
        print_success "Nginx reloaded successfully."
    else
        print_error "Nginx config test failed. Please check the configuration."
        return
    fi

    # Optional SSL
    if confirm "  Set up SSL with Let's Encrypt for $domain?"; then
        if ! command -v certbot &>/dev/null; then
            print_warn "Certbot not found. Installing..."
            if [[ "$PKG" == "apt" ]]; then
                pkg_install certbot python3-certbot-nginx
            else
                pkg_install certbot python3-certbot-nginx || sudo pip3 install certbot certbot-nginx
            fi
        fi
        read -rp "  Enter email for SSL certificate: " ssl_email
        if [[ -n "$ssl_email" ]]; then
            print_step "Requesting SSL certificate for $domain..."
            sudo certbot --nginx -d "$domain" --non-interactive --agree-tos -m "$ssl_email"
            print_success "SSL certificate installed for $domain"
        else
            print_warn "No email provided. Skipping SSL."
        fi
    fi
}

# ============================================================
#  3) Add static files site
# ============================================================

multisite_add_static() {
    echo -e "\n${CYAN}── Add Static Site ──${NC}"

    read -rp "  Domain name (e.g., www.example.com): " domain
    if [[ -z "$domain" ]]; then
        print_error "Domain name is required."
        return
    fi

    local config_path
    config_path=$(_site_config_path "$domain")
    if [[ -f "$config_path" ]]; then
        print_warn "Site config for '$domain' already exists."
        if ! confirm "  Overwrite existing config?"; then
            return
        fi
    fi

    read -rp "  Web root directory [default: /var/www/${domain}/html]: " web_root
    web_root=${web_root:-/var/www/${domain}/html}

    local spa_fallback="n"
    read -rp "  Enable SPA fallback (route all requests to index.html)? [y/N]: " spa_fallback
    spa_fallback=${spa_fallback:-n}

    print_step "Creating web root at $web_root..."
    sudo mkdir -p "$web_root"
    sudo chown -R "$USER:$USER" "$web_root"
    sudo chmod -R 755 "$web_root"
    print_success "Web root created with proper permissions."

    # Build try_files directive
    local try_files_directive
    if [[ "$spa_fallback" =~ ^[Yy]$ ]]; then
        try_files_directive='try_files $uri $uri/ /index.html;'
    else
        try_files_directive='try_files $uri $uri/ =404;'
    fi

    print_step "Creating Nginx static site config for $domain..."

    local config_content
    config_content=$(cat <<NGINXEOF
server {
    listen 80;
    server_name ${domain};

    root ${web_root};
    index index.html index.htm;

    location / {
        ${try_files_directive}
    }

    # Static asset caching
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot|mp4|webm|webp|avif)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_min_length 256;
    gzip_types
        text/plain
        text/css
        application/json
        application/javascript
        text/xml
        application/xml
        application/xml+rss
        text/javascript
        image/svg+xml
        application/vnd.ms-fontobject
        application/x-font-ttf
        font/opentype;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
}
NGINXEOF
)

    echo "$config_content" | sudo tee "$config_path" > /dev/null
    print_success "Config written to $config_path"

    # Enable the site
    _site_enable "$domain"
    print_success "Site '$domain' enabled."

    # Test and reload
    if sudo nginx -t 2>&1; then
        sudo systemctl reload nginx
        print_success "Nginx reloaded successfully."
    else
        print_error "Nginx config test failed. Please check the configuration."
        return
    fi

    # Optional SSL
    if confirm "  Set up SSL with Let's Encrypt for $domain?"; then
        if ! command -v certbot &>/dev/null; then
            print_warn "Certbot not found. Installing..."
            if [[ "$PKG" == "apt" ]]; then
                pkg_install certbot python3-certbot-nginx
            else
                pkg_install certbot python3-certbot-nginx || sudo pip3 install certbot certbot-nginx
            fi
        fi
        read -rp "  Enter email for SSL certificate: " ssl_email
        if [[ -n "$ssl_email" ]]; then
            print_step "Requesting SSL certificate for $domain..."
            sudo certbot --nginx -d "$domain" --non-interactive --agree-tos -m "$ssl_email"
            print_success "SSL certificate installed for $domain"
        else
            print_warn "No email provided. Skipping SSL."
        fi
    fi

    echo -e "\n  ${BOLD}Quick start:${NC}"
    echo -e "    Upload your files to: ${CYAN}${web_root}${NC}"
    echo -e "    scp -r ./dist/* ${USER}@server:${web_root}/"
}

# ============================================================
#  4) List all sites
# ============================================================

multisite_list() {
    echo -e "\n${CYAN}── Configured Sites ──${NC}"

    local sites
    sites=$(_site_list_names)

    if [[ -z "$sites" ]]; then
        print_warn "No sites configured."
        return
    fi

    printf "\n  ${BOLD}%-35s %-10s${NC}\n" "SITE" "STATUS"
    echo "  ────────────────────────────────────────────────"

    while IFS= read -r site; do
        if _site_is_enabled "$site"; then
            printf "  %-35s ${GREEN}%-10s${NC}\n" "$site" "enabled"
        else
            printf "  %-35s ${YELLOW}%-10s${NC}\n" "$site" "disabled"
        fi
    done <<< "$sites"

    echo ""
}

# ============================================================
#  5) Enable / disable a site
# ============================================================

multisite_toggle() {
    echo -e "\n${CYAN}── Enable / Disable Site ──${NC}"

    local sites
    sites=$(_site_list_names)

    if [[ -z "$sites" ]]; then
        print_warn "No sites configured."
        return
    fi

    local i=1
    local site_array=()
    while IFS= read -r site; do
        local status
        if _site_is_enabled "$site"; then
            status="${GREEN}enabled${NC}"
        else
            status="${YELLOW}disabled${NC}"
        fi
        echo -e "    ${i}) ${site}  [${status}]"
        site_array+=("$site")
        ((i++))
    done <<< "$sites"

    read -rp "  Select site number: " choice
    if [[ -z "$choice" ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt ${#site_array[@]} ]] 2>/dev/null; then
        print_error "Invalid selection."
        return
    fi

    local selected="${site_array[$((choice-1))]}"

    if _site_is_enabled "$selected"; then
        if confirm "  Site '$selected' is enabled. Disable it?"; then
            _site_disable "$selected"
            print_success "Site '$selected' disabled."
            if sudo nginx -t 2>&1; then
                sudo systemctl reload nginx
                print_success "Nginx reloaded."
            fi
        fi
    else
        if confirm "  Site '$selected' is disabled. Enable it?"; then
            _site_enable "$selected"
            print_success "Site '$selected' enabled."
            if sudo nginx -t 2>&1; then
                sudo systemctl reload nginx
                print_success "Nginx reloaded."
            else
                print_error "Nginx config test failed. Disabling site again."
                _site_disable "$selected"
            fi
        fi
    fi
}

# ============================================================
#  6) Remove a site
# ============================================================

multisite_remove() {
    echo -e "\n${CYAN}── Remove Site ──${NC}"

    local sites
    sites=$(_site_list_names)

    if [[ -z "$sites" ]]; then
        print_warn "No sites configured."
        return
    fi

    local i=1
    local site_array=()
    while IFS= read -r site; do
        echo -e "    ${i}) ${site}"
        site_array+=("$site")
        ((i++))
    done <<< "$sites"

    read -rp "  Select site number to remove: " choice
    if [[ -z "$choice" ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt ${#site_array[@]} ]] 2>/dev/null; then
        print_error "Invalid selection."
        return
    fi

    local selected="${site_array[$((choice-1))]}"

    if confirm "  ${RED}Remove site '$selected'? This cannot be undone.${NC}"; then
        # Disable first
        _site_disable "$selected"

        # Remove config file
        local config_path
        config_path=$(_site_config_path "$selected")
        sudo rm -f "$config_path"

        print_success "Site '$selected' removed."

        if sudo nginx -t 2>&1; then
            sudo systemctl reload nginx
            print_success "Nginx reloaded."
        fi
    fi
}

# ============================================================
#  7) Test Nginx config & reload
# ============================================================

multisite_test() {
    echo -e "\n${CYAN}── Nginx Config Test ──${NC}"

    print_step "Running nginx -t ..."
    echo ""
    if sudo nginx -t; then
        echo ""
        print_success "Nginx configuration test passed."
        if confirm "  Reload Nginx now?"; then
            sudo systemctl reload nginx
            print_success "Nginx reloaded successfully."
        fi
    else
        echo ""
        print_error "Nginx configuration test failed. Check the errors above."
    fi
}
