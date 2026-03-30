#!/bin/bash
# ============================================================
#  Web Server: Nginx, SSL, Node.js, PM2, Docker, Python
# ============================================================

install_node() {
    print_step "Installing Node.js..."
    echo -e "  Select Node.js version:"
    echo -e "    1) Node 18 LTS"
    echo -e "    2) Node 20 LTS"
    echo -e "    3) Node 22 LTS"
    read -rp "  Choice [1-3, default=2]: " node_choice
    node_choice=${node_choice:-2}

    case $node_choice in
        1) NODE_VER=18 ;;
        2) NODE_VER=20 ;;
        3) NODE_VER=22 ;;
        *) NODE_VER=20 ;;
    esac

    if [[ "$PKG" == "apt" ]]; then
        curl -fsSL "https://deb.nodesource.com/setup_${NODE_VER}.x" | sudo -E bash -
        sudo apt-get install -y nodejs
    else
        curl -fsSL "https://rpm.nodesource.com/setup_${NODE_VER}.x" | sudo bash -
        sudo yum install -y nodejs
    fi

    print_success "Node.js $(node -v) installed."
    sudo npm install -g npm@latest
    print_success "npm $(npm -v) updated."
}

install_pm2() {
    print_step "Installing PM2 (process manager)..."
    sudo npm install -g pm2
    pm2 startup systemd -u "$USER" --hp "$HOME" | tail -1 | sudo bash - || true
    print_success "PM2 installed and configured for startup."
}

install_nginx() {
    print_step "Installing Nginx..."
    if [[ "$PKG" == "apt" ]]; then
        pkg_install nginx
        sudo systemctl enable nginx
        sudo systemctl start nginx
    else
        sudo amazon-linux-extras install nginx1 2>/dev/null || pkg_install nginx
        sudo systemctl enable nginx
        sudo systemctl start nginx
    fi
    print_success "Nginx installed and running."
}

install_docker() {
    print_step "Installing Docker..."
    if [[ "$PKG" == "apt" ]]; then
        sudo apt-get install -y ca-certificates gnupg
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null || true
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt-get update -y
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    else
        sudo yum install -y docker
        sudo systemctl enable docker
        sudo systemctl start docker
    fi
    sudo usermod -aG docker "$USER"
    print_success "Docker installed. (Log out & back in for group changes.)"
}

install_python() {
    print_step "Installing Python..."
    if [[ "$PKG" == "apt" ]]; then
        pkg_install python3 python3-pip python3-venv
    else
        pkg_install python3 python3-pip
    fi
    print_success "Python $(python3 --version) installed."
}

install_certbot() {
    print_step "Installing Certbot for SSL..."
    if [[ "$PKG" == "apt" ]]; then
        pkg_install certbot python3-certbot-nginx
    else
        pkg_install certbot python3-certbot-nginx || {
            sudo pip3 install certbot certbot-nginx
        }
    fi
    print_success "Certbot installed."
}

# --- Configure Nginx reverse proxy for backend ---
configure_nginx_backend() {
    local port="$1"
    local domain="$2"

    if [[ -z "$domain" ]]; then
        local config_file="/etc/nginx/sites-available/backend"
    else
        local config_file="/etc/nginx/sites-available/$domain"
    fi

    print_step "Configuring Nginx reverse proxy (port $port)..."

    sudo tee "$config_file" > /dev/null <<NGINXCONF
server {
    listen 80;
    server_name ${domain:-_};

    location / {
        proxy_pass http://127.0.0.1:${port};
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
NGINXCONF

    if [[ "$PKG" == "apt" ]]; then
        sudo ln -sf "$config_file" /etc/nginx/sites-enabled/
        sudo rm -f /etc/nginx/sites-enabled/default
    else
        sudo cp "$config_file" /etc/nginx/conf.d/backend.conf
    fi

    sudo nginx -t && sudo systemctl reload nginx
    print_success "Nginx reverse proxy configured -> localhost:$port"
}

# --- Configure Nginx for static frontend ---
configure_nginx_frontend() {
    local web_root="$1"
    local domain="$2"

    if [[ -z "$domain" ]]; then
        local config_file="/etc/nginx/sites-available/frontend"
    else
        local config_file="/etc/nginx/sites-available/$domain"
    fi

    print_step "Configuring Nginx for static frontend..."

    sudo tee "$config_file" > /dev/null <<NGINXCONF
server {
    listen 80;
    server_name ${domain:-_};

    root ${web_root};
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml text/javascript image/svg+xml;
}
NGINXCONF

    if [[ "$PKG" == "apt" ]]; then
        sudo ln -sf "$config_file" /etc/nginx/sites-enabled/
        sudo rm -f /etc/nginx/sites-enabled/default
    else
        sudo cp "$config_file" /etc/nginx/conf.d/frontend.conf
    fi

    sudo mkdir -p "$web_root"
    sudo chown -R "$USER:$USER" "$web_root"
    sudo nginx -t && sudo systemctl reload nginx
    print_success "Nginx configured to serve static files from $web_root"
}

# --- SSL Setup ---
setup_ssl() {
    local domain="$1"
    if [[ -z "$domain" ]]; then
        print_warn "No domain provided. Skipping SSL."
        return
    fi
    read -rp "  Enter email for SSL certificate: " ssl_email
    if [[ -z "$ssl_email" ]]; then
        print_warn "No email provided. Skipping SSL."
        return
    fi
    print_step "Requesting SSL certificate for $domain..."
    sudo certbot --nginx -d "$domain" --non-interactive --agree-tos -m "$ssl_email"
    print_success "SSL certificate installed for $domain"
}
