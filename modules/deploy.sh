#!/bin/bash
# ============================================================
#  App Deployment Helpers
# ============================================================

setup_deploy() {
    echo -e "\n${CYAN}── App Deployment ──${NC}"

    echo -e "\n  Select deployment option:"
    echo -e "    1) Deploy app from Git repo"
    echo -e "    2) Install GitHub Actions self-hosted runner"
    echo -e "    3) Set up deploy keys for GitHub"
    echo -e "    4) Back to main menu"
    read -rp "  Choice [1-4]: " deploy_choice

    case $deploy_choice in
        1) deploy_from_git ;;
        2) install_gh_runner ;;
        3) setup_deploy_keys ;;
        4) return ;;
        *)
            print_error "Invalid choice."
            return
            ;;
    esac
}

deploy_from_git() {
    echo -e "\n${CYAN}── Deploy from Git Repository ──${NC}"

    read -rp "  Git repo URL: " repo_url
    if [[ -z "$repo_url" ]]; then
        print_error "Repository URL is required."
        return
    fi

    read -rp "  Branch [default: main]: " branch
    branch=${branch:-main}

    read -rp "  Deploy directory [default: /var/www/app]: " deploy_dir
    deploy_dir=${deploy_dir:-/var/www/app}

    # Clone the repo
    print_step "Cloning repository..."
    sudo mkdir -p "$deploy_dir"
    sudo chown "$USER":"$USER" "$deploy_dir"

    if [[ -d "$deploy_dir/.git" ]]; then
        print_warn "Directory already contains a Git repo. Pulling latest changes."
        git -C "$deploy_dir" fetch origin
        git -C "$deploy_dir" checkout "$branch"
        git -C "$deploy_dir" pull origin "$branch"
    else
        git clone -b "$branch" "$repo_url" "$deploy_dir"
    fi

    if [[ $? -ne 0 ]]; then
        print_error "Failed to clone repository."
        return
    fi
    print_success "Repository cloned to $deploy_dir."

    # Detect project type
    local project_type="unknown"

    if [[ -f "$deploy_dir/package.json" ]]; then
        project_type="node"
    elif [[ -f "$deploy_dir/requirements.txt" ]]; then
        project_type="python"
    elif [[ -f "$deploy_dir/Dockerfile" ]] || [[ -f "$deploy_dir/docker-compose.yml" ]]; then
        project_type="docker"
    elif [[ -f "$deploy_dir/Gemfile" ]]; then
        project_type="ruby"
    elif [[ -f "$deploy_dir/go.mod" ]]; then
        project_type="go"
    fi

    print_success "Detected project type: ${BOLD}$project_type${NC}"

    # Install dependencies based on type
    print_step "Installing dependencies..."
    case $project_type in
        node)
            cd "$deploy_dir" || return
            if [[ -f "yarn.lock" ]]; then
                npm install -g yarn 2>/dev/null
                yarn install --production
            elif [[ -f "pnpm-lock.yaml" ]]; then
                npm install -g pnpm 2>/dev/null
                pnpm install --prod
            else
                npm install --production
            fi
            print_success "Node.js dependencies installed."
            ;;
        python)
            cd "$deploy_dir" || return
            python3 -m venv venv
            source venv/bin/activate
            pip install -r requirements.txt
            print_success "Python dependencies installed."
            ;;
        docker)
            cd "$deploy_dir" || return
            if [[ -f "docker-compose.yml" ]] || [[ -f "compose.yml" ]]; then
                docker compose up -d
            else
                docker build -t "$(basename "$deploy_dir")" .
                print_success "Docker image built."
            fi
            print_success "Docker app deployed."
            return
            ;;
        ruby)
            cd "$deploy_dir" || return
            gem install bundler 2>/dev/null
            bundle install --deployment
            print_success "Ruby dependencies installed."
            ;;
        go)
            cd "$deploy_dir" || return
            go build -o app .
            print_success "Go binary built."
            ;;
        *)
            print_warn "Could not detect project type. Skipping dependency install."
            ;;
    esac

    # App port
    read -rp "  Enter app port [default: 3000]: " app_port
    app_port=${app_port:-3000}

    # Process manager
    echo -e "\n  Select process manager:"
    echo -e "    1) PM2 (Node.js recommended)"
    echo -e "    2) systemd service"
    read -rp "  Choice [1-2]: " pm_choice

    local app_name
    app_name=$(basename "$deploy_dir")

    case $pm_choice in
        1)
            print_step "Setting up PM2..."
            if ! command -v pm2 &>/dev/null; then
                sudo npm install -g pm2
                pm2 startup systemd -u "$USER" --hp "$HOME" | tail -1 | sudo bash - || true
            fi

            cd "$deploy_dir" || return
            if [[ "$project_type" == "node" ]]; then
                pm2 start npm --name "$app_name" -- start
            elif [[ "$project_type" == "python" ]]; then
                pm2 start "venv/bin/python" --name "$app_name" -- -m uvicorn main:app --host 0.0.0.0 --port "$app_port"
            else
                print_warn "PM2 start command may need manual adjustment for this project type."
                pm2 start "npm" --name "$app_name" -- start
            fi

            pm2 save
            print_success "PM2 process '$app_name' started and saved."
            ;;
        2)
            print_step "Creating systemd service..."

            local exec_start
            case $project_type in
                node)
                    exec_start="/usr/bin/npm start"
                    ;;
                python)
                    exec_start="$deploy_dir/venv/bin/python -m uvicorn main:app --host 0.0.0.0 --port $app_port"
                    ;;
                go)
                    exec_start="$deploy_dir/app"
                    ;;
                *)
                    read -rp "  Enter the start command for your app: " exec_start
                    ;;
            esac

            sudo tee "/etc/systemd/system/${app_name}.service" > /dev/null <<SVCEOF
[Unit]
Description=$app_name application
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$deploy_dir
ExecStart=$exec_start
Restart=on-failure
RestartSec=5
Environment=PORT=$app_port
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
SVCEOF

            sudo systemctl daemon-reload
            sudo systemctl enable "$app_name"
            sudo systemctl start "$app_name"
            print_success "systemd service '$app_name' created and started."
            ;;
        *)
            print_error "Invalid choice. Skipping process manager setup."
            ;;
    esac

    # Nginx reverse proxy
    if confirm "  Configure Nginx reverse proxy for this app?"; then
        if type configure_nginx_backend &>/dev/null; then
            read -rp "  Enter domain name (leave blank for IP-based access): " app_domain
            configure_nginx_backend "$app_port" "$app_domain"
        else
            print_warn "Nginx configuration function not available. Install Nginx first."
        fi
    fi

    echo -e "\n${GREEN}── App deployed successfully! ──${NC}"
    echo -e "
  ${BOLD}Summary:${NC}
    Repository : $repo_url
    Branch     : $branch
    Directory  : $deploy_dir
    Type       : $project_type
    Port       : $app_port
"
}

install_gh_runner() {
    echo -e "\n${CYAN}── GitHub Actions Self-Hosted Runner ──${NC}"

    read -rp "  GitHub repo URL (e.g. https://github.com/user/repo): " gh_repo
    if [[ -z "$gh_repo" ]]; then
        print_error "Repository URL is required."
        return
    fi

    read -rp "  Runner registration token: " runner_token
    if [[ -z "$runner_token" ]]; then
        print_error "Runner token is required."
        return
    fi

    local runner_dir="$HOME/actions-runner"

    print_step "Downloading GitHub Actions runner..."
    mkdir -p "$runner_dir"
    cd "$runner_dir" || return

    # Detect architecture
    local arch
    arch=$(uname -m)
    case $arch in
        x86_64)  arch="x64" ;;
        aarch64) arch="arm64" ;;
        armv7l)  arch="arm" ;;
    esac

    # Download latest runner
    local runner_url
    runner_url=$(curl -s https://api.github.com/repos/actions/runner/releases/latest \
        | grep "browser_download_url.*linux-${arch}" \
        | head -1 \
        | cut -d '"' -f 4)

    if [[ -z "$runner_url" ]]; then
        print_error "Could not determine runner download URL."
        return
    fi

    curl -o actions-runner.tar.gz -L "$runner_url"
    tar xzf actions-runner.tar.gz
    rm -f actions-runner.tar.gz
    print_success "Runner downloaded and extracted."

    # Configure
    print_step "Configuring runner..."
    read -rp "  Runner name [default: $(hostname)]: " runner_name
    runner_name=${runner_name:-$(hostname)}

    read -rp "  Runner labels (comma-separated) [default: self-hosted,linux]: " runner_labels
    runner_labels=${runner_labels:-self-hosted,linux}

    ./config.sh \
        --url "$gh_repo" \
        --token "$runner_token" \
        --name "$runner_name" \
        --labels "$runner_labels" \
        --unattended

    if [[ $? -ne 0 ]]; then
        print_error "Runner configuration failed."
        return
    fi
    print_success "Runner configured."

    # Install as service
    print_step "Installing runner as a service..."
    sudo ./svc.sh install
    sudo ./svc.sh start
    print_success "GitHub Actions runner installed and running as a service."

    echo -e "
  ${BOLD}Runner details:${NC}
    Directory : $runner_dir
    Name      : $runner_name
    Labels    : $runner_labels
    Repo      : $gh_repo

  ${YELLOW}Manage with:${NC}
    sudo ./svc.sh status
    sudo ./svc.sh stop
    sudo ./svc.sh start
"
}

setup_deploy_keys() {
    echo -e "\n${CYAN}── GitHub Deploy Keys ──${NC}"

    local key_file="$HOME/.ssh/deploy_key"

    if [[ -f "$key_file" ]]; then
        print_warn "Deploy key already exists at $key_file."
        if ! confirm "  Overwrite existing key?"; then
            echo -e "\n  ${BOLD}Existing public key:${NC}"
            cat "${key_file}.pub"
            return
        fi
    fi

    # Generate key
    print_step "Generating ed25519 deploy key..."
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    read -rp "  Comment/label for this key [default: deploy@$(hostname)]: " key_comment
    key_comment=${key_comment:-"deploy@$(hostname)"}

    ssh-keygen -t ed25519 -C "$key_comment" -f "$key_file" -N ""

    if [[ $? -ne 0 ]]; then
        print_error "Failed to generate deploy key."
        return
    fi

    chmod 600 "$key_file"
    chmod 644 "${key_file}.pub"
    print_success "Deploy key generated: $key_file"

    # Configure SSH config
    print_step "Configuring SSH for GitHub deploy key..."
    local ssh_config="$HOME/.ssh/config"

    # Remove existing github.com deploy block if present
    if [[ -f "$ssh_config" ]] && grep -q "# deploy-key-start" "$ssh_config"; then
        sed -i '/# deploy-key-start/,/# deploy-key-end/d' "$ssh_config"
    fi

    cat >> "$ssh_config" <<SSHEOF

# deploy-key-start
Host github.com
    HostName github.com
    User git
    IdentityFile $key_file
    IdentitiesOnly yes
# deploy-key-end
SSHEOF

    chmod 600 "$ssh_config"
    print_success "SSH config updated for github.com."

    # Display public key
    echo -e "\n  ${BOLD}Your deploy public key (add to GitHub repository settings):${NC}"
    echo -e "  ${YELLOW}Settings > Deploy keys > Add deploy key${NC}\n"
    cat "${key_file}.pub"

    echo -e "\n  ${BOLD}Test with:${NC} ssh -T git@github.com"
}
