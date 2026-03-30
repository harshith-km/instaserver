#!/bin/bash
# ============================================================
#  SSH Setup & Hardening
# ============================================================

setup_ssh() {
    echo -e "\n${CYAN}── SSH Setup & Hardening ──${NC}"

    local sshd_config="/etc/ssh/sshd_config"

    echo -e "\n  Select SSH options to configure:"
    echo -e "    1) Change SSH port"
    echo -e "    2) Disable root login"
    echo -e "    3) Disable password authentication (key-only)"
    echo -e "    4) Add authorized SSH public key"
    echo -e "    5) Create a new sudo user with SSH access"
    echo -e "    6) Install & configure Fail2Ban"
    echo -e "    7) Set SSH idle timeout"
    echo -e "    8) All of the above (full hardening)"
    echo -e "    9) Back to main menu"
    read -rp "  Choice [1-9]: " ssh_choice

    case $ssh_choice in
        1) ssh_change_port ;;
        2) ssh_disable_root ;;
        3) ssh_disable_password ;;
        4) ssh_add_key ;;
        5) ssh_create_user ;;
        6) ssh_install_fail2ban ;;
        7) ssh_idle_timeout ;;
        8)
            ssh_change_port
            ssh_disable_root
            ssh_disable_password
            ssh_add_key
            ssh_create_user
            ssh_install_fail2ban
            ssh_idle_timeout
            ;;
        9) return ;;
        *) print_error "Invalid choice."; return ;;
    esac

    print_step "Restarting SSH service..."
    sudo systemctl restart sshd
    print_success "SSH configuration updated and service restarted."

    echo -e "\n${YELLOW}  IMPORTANT: Test your SSH connection in a NEW terminal${NC}"
    echo -e "${YELLOW}  before closing this session to avoid lockout!${NC}"
}

ssh_change_port() {
    local sshd_config="/etc/ssh/sshd_config"
    read -rp "  Enter new SSH port [default: 22]: " new_port
    new_port=${new_port:-22}

    print_step "Changing SSH port to $new_port..."
    sudo sed -i "s/^#\?Port .*/Port $new_port/" "$sshd_config"

    # Update firewall
    if [[ "$PKG" == "apt" ]]; then
        sudo ufw allow "$new_port/tcp" 2>/dev/null || true
    else
        sudo firewall-cmd --permanent --add-port="${new_port}/tcp" 2>/dev/null || true
        sudo firewall-cmd --reload 2>/dev/null || true
    fi
    print_success "SSH port changed to $new_port."
}

ssh_disable_root() {
    local sshd_config="/etc/ssh/sshd_config"
    print_step "Disabling root login via SSH..."
    sudo sed -i "s/^#\?PermitRootLogin .*/PermitRootLogin no/" "$sshd_config"
    print_success "Root login disabled."
}

ssh_disable_password() {
    local sshd_config="/etc/ssh/sshd_config"
    print_step "Disabling password authentication..."
    sudo sed -i "s/^#\?PasswordAuthentication .*/PasswordAuthentication no/" "$sshd_config"
    sudo sed -i "s/^#\?ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/" "$sshd_config"
    print_success "Password authentication disabled (key-only access)."
}

ssh_add_key() {
    read -rp "  Enter the username to add key for [default: $USER]: " key_user
    key_user=${key_user:-$USER}

    local user_home
    user_home=$(eval echo "~$key_user")
    local auth_keys="$user_home/.ssh/authorized_keys"

    sudo mkdir -p "$user_home/.ssh"
    sudo chmod 700 "$user_home/.ssh"

    echo -e "  Paste your public SSH key (ssh-rsa ... or ssh-ed25519 ...):"
    read -rp "  > " pub_key

    if [[ -z "$pub_key" ]]; then
        print_warn "No key provided. Skipping."
        return
    fi

    echo "$pub_key" | sudo tee -a "$auth_keys" > /dev/null
    sudo chmod 600 "$auth_keys"
    sudo chown -R "$key_user:$key_user" "$user_home/.ssh"
    print_success "Public key added for $key_user."
}

ssh_create_user() {
    read -rp "  Enter new username: " new_user
    if [[ -z "$new_user" ]]; then
        print_warn "No username provided. Skipping."
        return
    fi

    print_step "Creating user '$new_user' with sudo access..."
    sudo adduser --disabled-password --gecos "" "$new_user" 2>/dev/null || sudo useradd -m "$new_user"
    sudo usermod -aG sudo "$new_user" 2>/dev/null || sudo usermod -aG wheel "$new_user"

    # Set up SSH directory
    local user_home
    user_home=$(eval echo "~$new_user")
    sudo mkdir -p "$user_home/.ssh"
    sudo chmod 700 "$user_home/.ssh"

    echo -e "  Paste the public SSH key for $new_user (or leave blank to skip):"
    read -rp "  > " new_user_key

    if [[ -n "$new_user_key" ]]; then
        echo "$new_user_key" | sudo tee "$user_home/.ssh/authorized_keys" > /dev/null
        sudo chmod 600 "$user_home/.ssh/authorized_keys"
    fi

    sudo chown -R "$new_user:$new_user" "$user_home/.ssh"

    if confirm "  Set a password for $new_user?"; then
        sudo passwd "$new_user"
    fi

    print_success "User '$new_user' created with sudo access."
}

ssh_install_fail2ban() {
    print_step "Installing Fail2Ban..."
    if [[ "$PKG" == "apt" ]]; then
        pkg_install fail2ban
    else
        pkg_install fail2ban || {
            sudo amazon-linux-extras install epel -y 2>/dev/null || true
            pkg_install fail2ban
        }
    fi

    # Configure jail for SSH
    sudo tee /etc/fail2ban/jail.local > /dev/null <<'F2BCONF'
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port    = ssh
filter  = sshd
logpath = /var/log/auth.log
F2BCONF

    # Amazon Linux uses a different log path
    if [[ "$OS" == "amzn" ]]; then
        sudo sed -i 's|/var/log/auth.log|/var/log/secure|' /etc/fail2ban/jail.local
    fi

    sudo systemctl enable fail2ban
    sudo systemctl start fail2ban
    print_success "Fail2Ban installed (5 failures = 1 hour ban)."
}

ssh_idle_timeout() {
    local sshd_config="/etc/ssh/sshd_config"
    read -rp "  SSH idle timeout in seconds [default: 900 (15 min)]: " idle_timeout
    idle_timeout=${idle_timeout:-900}

    print_step "Setting SSH idle timeout to ${idle_timeout}s..."
    sudo sed -i "s/^#\?ClientAliveInterval .*/ClientAliveInterval $idle_timeout/" "$sshd_config"
    sudo sed -i "s/^#\?ClientAliveCountMax .*/ClientAliveCountMax 2/" "$sshd_config"
    print_success "SSH idle timeout set to ${idle_timeout}s."
}
