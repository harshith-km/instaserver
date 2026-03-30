#!/bin/bash
# ============================================================
#  Security Scanning & Hardening Checks
# ============================================================

setup_security() {
    while true; do
        echo -e "\n${CYAN}── Security Scanning & Hardening ──${NC}"
        echo -e "    1) Run port scan (self-scan)"
        echo -e "    2) Check for common security issues"
        echo -e "    3) Check for default/weak configurations"
        echo -e "    4) Run CIS benchmark checks (basic)"
        echo -e "    5) Set up unattended security updates"
        echo -e "    0) Back to main menu"
        read -rp "  Choice [0-5]: " sec_choice

        case $sec_choice in
            1) security_port_scan ;;
            2) security_check ;;
            3) security_weak_config ;;
            4) security_cis_basic ;;
            5) security_auto_updates ;;
            0) return ;;
            *) print_error "Invalid choice." ;;
        esac
    done
}

security_port_scan() {
    print_step "Running port scan on this server..."

    if ! command -v nmap &>/dev/null; then
        print_warn "nmap is not installed."
        if confirm "  Install nmap?"; then
            pkg_install nmap
        else
            print_error "nmap is required for port scanning."
            return
        fi
    fi

    local pub_ip
    pub_ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null)

    if [[ -z "$pub_ip" ]]; then
        print_warn "Could not detect public IP. Scanning localhost instead."
        pub_ip="127.0.0.1"
    fi

    echo -e "\n  ${BOLD}Scanning $pub_ip for common ports...${NC}\n"
    sudo nmap -sT -T4 --top-ports 1000 "$pub_ip" 2>/dev/null

    echo -e ""

    # Warn about unexpected ports
    local expected_ports=("22" "80" "443")
    local open_ports
    open_ports=$(sudo nmap -sT -T4 --top-ports 1000 "$pub_ip" 2>/dev/null | grep "^[0-9]" | grep "open" | awk -F/ '{print $1}')

    if [[ -n "$open_ports" ]]; then
        echo -e "  ${BOLD}Open ports found:${NC}"
        while IFS= read -r port; do
            local is_expected=false
            for exp in "${expected_ports[@]}"; do
                if [[ "$port" == "$exp" ]]; then
                    is_expected=true
                    break
                fi
            done
            if $is_expected; then
                echo -e "    ${GREEN}●${NC} Port $port (expected)"
            else
                echo -e "    ${YELLOW}●${NC} Port $port ${YELLOW}(unexpected — review if needed)${NC}"
            fi
        done <<< "$open_ports"
    fi

    print_success "Port scan complete."
}

security_check() {
    print_step "Running common security checks..."

    local pass=0
    local fail=0
    local total=0
    local sshd_config="/etc/ssh/sshd_config"

    echo -e "\n  ${BOLD}Security Check Results:${NC}\n"

    # 1. Root SSH access
    total=$((total + 1))
    local root_login
    root_login=$(grep -i "^PermitRootLogin" "$sshd_config" 2>/dev/null | awk '{print $2}')
    if [[ "$root_login" == "no" ]]; then
        echo -e "  ${GREEN}[PASS]${NC} Root SSH login is disabled"
        pass=$((pass + 1))
    else
        echo -e "  ${RED}[FAIL]${NC} Root SSH login is ${BOLD}enabled${NC} (PermitRootLogin: ${root_login:-default})"
        fail=$((fail + 1))
    fi

    # 2. Password authentication
    total=$((total + 1))
    local pass_auth
    pass_auth=$(grep -i "^PasswordAuthentication" "$sshd_config" 2>/dev/null | awk '{print $2}')
    if [[ "$pass_auth" == "no" ]]; then
        echo -e "  ${GREEN}[PASS]${NC} SSH password authentication is disabled"
        pass=$((pass + 1))
    else
        echo -e "  ${RED}[FAIL]${NC} SSH password authentication is ${BOLD}enabled${NC}"
        fail=$((fail + 1))
    fi

    # 3. Default SSH port
    total=$((total + 1))
    local ssh_port
    ssh_port=$(grep -i "^Port" "$sshd_config" 2>/dev/null | awk '{print $2}')
    ssh_port=${ssh_port:-22}
    if [[ "$ssh_port" != "22" ]]; then
        echo -e "  ${GREEN}[PASS]${NC} SSH is on non-default port ($ssh_port)"
        pass=$((pass + 1))
    else
        echo -e "  ${YELLOW}[WARN]${NC} SSH is on default port 22"
        fail=$((fail + 1))
    fi

    # 4. Firewall active
    total=$((total + 1))
    if sudo ufw status 2>/dev/null | grep -q "active"; then
        echo -e "  ${GREEN}[PASS]${NC} UFW firewall is active"
        pass=$((pass + 1))
    elif systemctl is-active --quiet firewalld 2>/dev/null; then
        echo -e "  ${GREEN}[PASS]${NC} firewalld is active"
        pass=$((pass + 1))
    elif sudo iptables -L -n 2>/dev/null | grep -q "Chain INPUT"; then
        echo -e "  ${YELLOW}[WARN]${NC} iptables has rules, but no managed firewall detected"
        fail=$((fail + 1))
    else
        echo -e "  ${RED}[FAIL]${NC} No active firewall detected"
        fail=$((fail + 1))
    fi

    # 5. Unattended upgrades
    total=$((total + 1))
    if dpkg -l unattended-upgrades 2>/dev/null | grep -q "^ii"; then
        echo -e "  ${GREEN}[PASS]${NC} Unattended upgrades is installed"
        pass=$((pass + 1))
    elif systemctl is-active --quiet yum-cron 2>/dev/null; then
        echo -e "  ${GREEN}[PASS]${NC} yum-cron (auto updates) is active"
        pass=$((pass + 1))
    else
        echo -e "  ${RED}[FAIL]${NC} No automatic security updates configured"
        fail=$((fail + 1))
    fi

    # 6. Fail2ban running
    total=$((total + 1))
    if systemctl is-active --quiet fail2ban 2>/dev/null; then
        echo -e "  ${GREEN}[PASS]${NC} Fail2ban is running"
        pass=$((pass + 1))
    else
        echo -e "  ${RED}[FAIL]${NC} Fail2ban is not running"
        fail=$((fail + 1))
    fi

    # 7. /etc/shadow permissions
    total=$((total + 1))
    local shadow_perms
    shadow_perms=$(stat -c "%a" /etc/shadow 2>/dev/null)
    if [[ "$shadow_perms" == "640" || "$shadow_perms" == "600" || "$shadow_perms" == "000" ]]; then
        echo -e "  ${GREEN}[PASS]${NC} /etc/shadow permissions are restrictive ($shadow_perms)"
        pass=$((pass + 1))
    else
        echo -e "  ${RED}[FAIL]${NC} /etc/shadow has loose permissions ($shadow_perms)"
        fail=$((fail + 1))
    fi

    # 8. World-readable .env files
    total=$((total + 1))
    local env_files
    env_files=$(find /home /var/www /srv /opt -name ".env" -perm -o=r 2>/dev/null | head -5)
    if [[ -z "$env_files" ]]; then
        echo -e "  ${GREEN}[PASS]${NC} No world-readable .env files found"
        pass=$((pass + 1))
    else
        echo -e "  ${RED}[FAIL]${NC} World-readable .env files found:"
        while IFS= read -r f; do
            echo -e "         $f"
        done <<< "$env_files"
        fail=$((fail + 1))
    fi

    echo -e "\n  ─────────────────────────────────────"
    echo -e "  ${BOLD}Score: ${pass}/${total} checks passed${NC}"

    if [[ $fail -eq 0 ]]; then
        print_success "All security checks passed!"
    else
        print_warn "$fail issue(s) found. Review the items above."
    fi
}

security_weak_config() {
    print_step "Checking for default/weak configurations..."

    echo -e "\n  ${BOLD}Weak Configuration Check Results:${NC}\n"

    # 1. MySQL default password
    if command -v mysql &>/dev/null; then
        if mysql -u root --password="" -e "SELECT 1" &>/dev/null 2>&1; then
            echo -e "  ${RED}[FAIL]${NC} MySQL root has ${BOLD}no password${NC}"
            echo -e "         ${CYAN}Fix: ALTER USER 'root'@'localhost' IDENTIFIED BY 'strong_password';${NC}"
        elif mysql -u root --password="root" -e "SELECT 1" &>/dev/null 2>&1; then
            echo -e "  ${RED}[FAIL]${NC} MySQL root has default password 'root'"
            echo -e "         ${CYAN}Fix: ALTER USER 'root'@'localhost' IDENTIFIED BY 'strong_password';${NC}"
        elif mysql -u root --password="password" -e "SELECT 1" &>/dev/null 2>&1; then
            echo -e "  ${RED}[FAIL]${NC} MySQL root has default password 'password'"
            echo -e "         ${CYAN}Fix: ALTER USER 'root'@'localhost' IDENTIFIED BY 'strong_password';${NC}"
        else
            echo -e "  ${GREEN}[PASS]${NC} MySQL root does not use common default passwords"
        fi
    else
        echo -e "  ${BLUE}[SKIP]${NC} MySQL not installed"
    fi

    # 2. PostgreSQL default password
    if command -v psql &>/dev/null; then
        if PGPASSWORD="postgres" psql -U postgres -c "SELECT 1" &>/dev/null 2>&1; then
            echo -e "  ${RED}[FAIL]${NC} PostgreSQL 'postgres' user has default password"
            echo -e "         ${CYAN}Fix: ALTER USER postgres PASSWORD 'strong_password';${NC}"
        else
            echo -e "  ${GREEN}[PASS]${NC} PostgreSQL does not use default password for 'postgres'"
        fi
    else
        echo -e "  ${BLUE}[SKIP]${NC} PostgreSQL not installed"
    fi

    # 3. Redis without password
    if command -v redis-cli &>/dev/null; then
        local redis_resp
        redis_resp=$(redis-cli PING 2>/dev/null)
        if [[ "$redis_resp" == "PONG" ]]; then
            echo -e "  ${RED}[FAIL]${NC} Redis is accessible ${BOLD}without authentication${NC}"
            echo -e "         ${CYAN}Fix: Set 'requirepass' in /etc/redis/redis.conf${NC}"
        else
            echo -e "  ${GREEN}[PASS]${NC} Redis requires authentication"
        fi
    else
        echo -e "  ${BLUE}[SKIP]${NC} Redis not installed"
    fi

    # 4. MongoDB without auth
    if command -v mongosh &>/dev/null || command -v mongo &>/dev/null; then
        local mongo_cmd="mongosh"
        command -v mongosh &>/dev/null || mongo_cmd="mongo"
        if $mongo_cmd --eval "db.adminCommand('ping')" &>/dev/null 2>&1; then
            echo -e "  ${RED}[FAIL]${NC} MongoDB is accessible ${BOLD}without authentication${NC}"
            echo -e "         ${CYAN}Fix: Enable authorization in /etc/mongod.conf and create admin user${NC}"
        else
            echo -e "  ${GREEN}[PASS]${NC} MongoDB requires authentication"
        fi
    else
        echo -e "  ${BLUE}[SKIP]${NC} MongoDB not installed"
    fi

    # 5. Nginx server_tokens
    if command -v nginx &>/dev/null; then
        local nginx_conf="/etc/nginx/nginx.conf"
        if grep -q "server_tokens off" "$nginx_conf" 2>/dev/null; then
            echo -e "  ${GREEN}[PASS]${NC} Nginx server_tokens is off (version hidden)"
        elif grep -q "server_tokens on" "$nginx_conf" 2>/dev/null; then
            echo -e "  ${RED}[FAIL]${NC} Nginx server_tokens is ${BOLD}on${NC} (version exposed)"
            echo -e "         ${CYAN}Fix: Add 'server_tokens off;' in nginx.conf http block${NC}"
        else
            echo -e "  ${YELLOW}[WARN]${NC} Nginx server_tokens not explicitly set (defaults to on)"
            echo -e "         ${CYAN}Fix: Add 'server_tokens off;' in nginx.conf http block${NC}"
        fi
    else
        echo -e "  ${BLUE}[SKIP]${NC} Nginx not installed"
    fi

    echo -e ""
    print_success "Weak configuration check complete."
}

security_cis_basic() {
    print_step "Running basic CIS benchmark checks..."

    local pass=0
    local total=0
    local sshd_config="/etc/ssh/sshd_config"

    echo -e "\n  ${BOLD}CIS Benchmark (Basic) Results:${NC}\n"

    # 1. /tmp separate partition
    total=$((total + 1))
    if mount | grep -q " /tmp "; then
        echo -e "  ${GREEN}[PASS]${NC} /tmp is on a separate partition"
        pass=$((pass + 1))
    else
        echo -e "  ${RED}[FAIL]${NC} /tmp is not on a separate partition"
    fi

    # 2. Sticky bit on world-writable directories
    total=$((total + 1))
    local no_sticky
    no_sticky=$(find / -xdev -type d \( -perm -0002 -a ! -perm -1000 \) 2>/dev/null | head -5)
    if [[ -z "$no_sticky" ]]; then
        echo -e "  ${GREEN}[PASS]${NC} All world-writable directories have sticky bit set"
        pass=$((pass + 1))
    else
        echo -e "  ${RED}[FAIL]${NC} World-writable directories without sticky bit:"
        while IFS= read -r d; do
            echo -e "         $d"
        done <<< "$no_sticky"
    fi

    # 3. No empty password fields in /etc/shadow
    total=$((total + 1))
    local empty_pass
    empty_pass=$(sudo awk -F: '($2 == "" ) {print $1}' /etc/shadow 2>/dev/null)
    if [[ -z "$empty_pass" ]]; then
        echo -e "  ${GREEN}[PASS]${NC} No accounts with empty password fields"
        pass=$((pass + 1))
    else
        echo -e "  ${RED}[FAIL]${NC} Accounts with empty passwords: $empty_pass"
    fi

    # 4. SSH Protocol version (modern OpenSSH defaults to 2, check for explicit 1)
    total=$((total + 1))
    if grep -qi "^Protocol 1" "$sshd_config" 2>/dev/null; then
        echo -e "  ${RED}[FAIL]${NC} SSH Protocol version 1 is enabled"
    else
        echo -e "  ${GREEN}[PASS]${NC} SSH is not using Protocol version 1"
        pass=$((pass + 1))
    fi

    # 5. SSH MaxAuthTries
    total=$((total + 1))
    local max_auth
    max_auth=$(grep -i "^MaxAuthTries" "$sshd_config" 2>/dev/null | awk '{print $2}')
    if [[ -n "$max_auth" && "$max_auth" -le 4 ]]; then
        echo -e "  ${GREEN}[PASS]${NC} SSH MaxAuthTries is set to $max_auth"
        pass=$((pass + 1))
    elif [[ -n "$max_auth" ]]; then
        echo -e "  ${YELLOW}[WARN]${NC} SSH MaxAuthTries is $max_auth (recommended: 4 or less)"
    else
        echo -e "  ${YELLOW}[WARN]${NC} SSH MaxAuthTries not explicitly set (default: 6)"
    fi

    # 6. No UID 0 accounts besides root
    total=$((total + 1))
    local uid0_users
    uid0_users=$(awk -F: '($3 == 0) {print $1}' /etc/passwd 2>/dev/null)
    if [[ "$uid0_users" == "root" ]]; then
        echo -e "  ${GREEN}[PASS]${NC} Only root has UID 0"
        pass=$((pass + 1))
    else
        echo -e "  ${RED}[FAIL]${NC} Multiple accounts with UID 0: $uid0_users"
    fi

    # 7. Root is the only account with GID 0
    total=$((total + 1))
    local gid0_count
    gid0_count=$(awk -F: '($4 == 0)' /etc/passwd 2>/dev/null | wc -l)
    if [[ "$gid0_count" -le 1 ]]; then
        echo -e "  ${GREEN}[PASS]${NC} Only root has GID 0"
        pass=$((pass + 1))
    else
        echo -e "  ${YELLOW}[WARN]${NC} $gid0_count accounts have GID 0"
    fi

    # 8. SSH LoginGraceTime
    total=$((total + 1))
    local grace_time
    grace_time=$(grep -i "^LoginGraceTime" "$sshd_config" 2>/dev/null | awk '{print $2}')
    if [[ -n "$grace_time" && "$grace_time" -le 60 ]]; then
        echo -e "  ${GREEN}[PASS]${NC} SSH LoginGraceTime is set to $grace_time"
        pass=$((pass + 1))
    else
        echo -e "  ${YELLOW}[WARN]${NC} SSH LoginGraceTime is ${grace_time:-not set} (recommended: 60 or less)"
    fi

    # 9. Core dumps restricted
    total=$((total + 1))
    if grep -q "hard core 0" /etc/security/limits.conf 2>/dev/null; then
        echo -e "  ${GREEN}[PASS]${NC} Core dumps are restricted"
        pass=$((pass + 1))
    else
        echo -e "  ${YELLOW}[WARN]${NC} Core dumps are not explicitly restricted in limits.conf"
    fi

    # 10. ASLR enabled
    total=$((total + 1))
    local aslr
    aslr=$(cat /proc/sys/kernel/randomize_va_space 2>/dev/null)
    if [[ "$aslr" == "2" ]]; then
        echo -e "  ${GREEN}[PASS]${NC} Address Space Layout Randomization (ASLR) is enabled"
        pass=$((pass + 1))
    else
        echo -e "  ${RED}[FAIL]${NC} ASLR is not fully enabled (value: ${aslr:-unknown})"
    fi

    echo -e "\n  ─────────────────────────────────────"
    echo -e "  ${BOLD}Score: ${pass}/${total} checks passed${NC}"

    if [[ $pass -eq $total ]]; then
        print_success "All CIS basic checks passed!"
    elif [[ $pass -ge $((total * 7 / 10)) ]]; then
        print_warn "Most checks passed, but some items need attention."
    else
        print_error "Several checks failed. Review the items above and harden your system."
    fi
}

security_auto_updates() {
    print_step "Setting up unattended security updates..."

    if [[ "$PKG" == "apt" ]]; then
        pkg_install unattended-upgrades apt-listchanges

        sudo tee /etc/apt/apt.conf.d/20auto-upgrades > /dev/null <<'AUTOCONF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
AUTOCONF

        # Ensure security updates are enabled
        if [[ -f /etc/apt/apt.conf.d/50unattended-upgrades ]]; then
            print_success "Unattended upgrades config exists."
        else
            sudo tee /etc/apt/apt.conf.d/50unattended-upgrades > /dev/null <<'UUCONF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
UUCONF
        fi

        print_success "Unattended upgrades configured (Debian/Ubuntu)."
        echo -e "  ${BOLD}Config:${NC} /etc/apt/apt.conf.d/50unattended-upgrades"
        echo -e "  ${BOLD}Tip:${NC}    Run 'sudo unattended-upgrade --dry-run' to test."

    else
        pkg_install yum-cron

        sudo sed -i 's/^update_cmd.*/update_cmd = security/' /etc/yum/yum-cron.conf 2>/dev/null || true
        sudo sed -i 's/^apply_updates.*/apply_updates = yes/' /etc/yum/yum-cron.conf 2>/dev/null || true

        sudo systemctl enable yum-cron
        sudo systemctl start yum-cron

        print_success "yum-cron configured for automatic security updates."
        echo -e "  ${BOLD}Config:${NC} /etc/yum/yum-cron.conf"
    fi

    if confirm "  Also install and enable Fail2ban for brute-force protection?"; then
        if [[ "$PKG" == "apt" ]]; then
            pkg_install fail2ban
        else
            pkg_install fail2ban 2>/dev/null || {
                sudo amazon-linux-extras install epel -y 2>/dev/null || true
                pkg_install fail2ban
            }
        fi
        sudo systemctl enable fail2ban
        sudo systemctl start fail2ban
        print_success "Fail2ban installed and running."
    fi
}
