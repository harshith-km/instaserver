#!/bin/bash

# ============================================================
#  EC2 Instance Setup Script
#  Supports: Ubuntu Server / Amazon Linux
# ============================================================

set -e

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
    echo "║           EC2 Instance Setup Script              ║"
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

# ============================================================
#  SSH SETUP & HARDENING
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

# ============================================================
#  DATABASE SETUP
# ============================================================
setup_database() {
    echo -e "\n${CYAN}── Database Setup ──${NC}"

    echo -e "\n  Select database to install:"
    echo -e "    1) PostgreSQL"
    echo -e "    2) MySQL / MariaDB"
    echo -e "    3) MongoDB"
    echo -e "    4) Redis"
    echo -e "    5) Multiple (select one by one)"
    echo -e "    6) Back to main menu"
    read -rp "  Choice [1-6]: " db_choice

    case $db_choice in
        1) install_postgresql ;;
        2) install_mysql ;;
        3) install_mongodb ;;
        4) install_redis ;;
        5)
            if confirm "  Install PostgreSQL?"; then install_postgresql; fi
            if confirm "  Install MySQL/MariaDB?"; then install_mysql; fi
            if confirm "  Install MongoDB?"; then install_mongodb; fi
            if confirm "  Install Redis?"; then install_redis; fi
            ;;
        6) return ;;
        *) print_error "Invalid choice."; return ;;
    esac
}

install_postgresql() {
    print_step "Installing PostgreSQL..."
    if [[ "$PKG" == "apt" ]]; then
        pkg_install postgresql postgresql-contrib
    else
        pkg_install postgresql-server postgresql
        sudo postgresql-setup --initdb 2>/dev/null || sudo postgresql-setup initdb
    fi
    sudo systemctl enable postgresql
    sudo systemctl start postgresql
    print_success "PostgreSQL installed and running."
    echo -e "  ${BOLD}Tip:${NC} sudo -u postgres psql  (to access the shell)"
}

install_mysql() {
    print_step "Installing MySQL/MariaDB..."
    if [[ "$PKG" == "apt" ]]; then
        pkg_install mysql-server
        sudo systemctl enable mysql
        sudo systemctl start mysql
    else
        pkg_install mariadb-server mariadb
        sudo systemctl enable mariadb
        sudo systemctl start mariadb
    fi

    if confirm "  Run mysql_secure_installation now?"; then
        sudo mysql_secure_installation
    fi
    print_success "MySQL/MariaDB installed and running."
}

install_mongodb() {
    print_step "Installing MongoDB..."
    if [[ "$PKG" == "apt" ]]; then
        curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | sudo gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg 2>/dev/null || true
        echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
        sudo apt-get update
        pkg_install mongodb-org
    else
        sudo tee /etc/yum.repos.d/mongodb-org-7.0.repo > /dev/null <<'MONGOREPO'
[mongodb-org-7.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/amazon/2023/mongodb-org/7.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://pgp.mongodb.com/server-7.0.asc
MONGOREPO
        pkg_install mongodb-org
    fi
    sudo systemctl enable mongod
    sudo systemctl start mongod
    print_success "MongoDB installed and running."
}

install_redis() {
    print_step "Installing Redis..."
    if [[ "$PKG" == "apt" ]]; then
        pkg_install redis-server
        sudo systemctl enable redis-server
        sudo systemctl start redis-server
    else
        pkg_install redis
        sudo systemctl enable redis
        sudo systemctl start redis
    fi
    print_success "Redis installed and running."
}

# ============================================================
#  MONITORING & SECURITY
# ============================================================
setup_monitoring() {
    echo -e "\n${CYAN}── Monitoring, Logging & Security ──${NC}"

    echo -e "\n  ${BOLD}CLI Monitoring Tools${NC}"
    echo -e "    1) htop, iotop, sysstat, nmon (system monitoring)"
    echo -e "    2) glances (all-in-one system monitor)"
    echo -e "    3) ctop (container monitoring for Docker)"
    echo -e ""
    echo -e "  ${BOLD}Dashboard / Web Monitoring${NC}"
    echo -e "    4) Netdata (real-time web dashboard)"
    echo -e "    5) Prometheus Node Exporter (metrics exporter)"
    echo -e "    6) Grafana (visualization dashboard)"
    echo -e ""
    echo -e "  ${BOLD}Log Management${NC}"
    echo -e "    7) Logrotate config (rotate app logs)"
    echo -e "    8) GoAccess (real-time Nginx/Apache log analyzer)"
    echo -e ""
    echo -e "  ${BOLD}AWS & Security${NC}"
    echo -e "    9) CloudWatch Agent (AWS monitoring)"
    echo -e "   10) Automatic security updates"
    echo -e "   11) Lynis (security auditing)"
    echo -e ""
    echo -e "  ${BOLD}Uptime & Alerts${NC}"
    echo -e "   12) Setup disk/memory/CPU alert script (cron)"
    echo -e ""
    echo -e "   13) Install ALL CLI tools (1+2+3)"
    echo -e "   14) Full monitoring stack (1+2+4+7+10+12)"
    echo -e "    0) Back to main menu"
    read -rp "  Choice [0-14]: " mon_choice

    case $mon_choice in
        1)  install_sysmon ;;
        2)  install_glances ;;
        3)  install_ctop ;;
        4)  install_netdata ;;
        5)  install_node_exporter ;;
        6)  install_grafana ;;
        7)  setup_logrotate ;;
        8)  install_goaccess ;;
        9)  install_cloudwatch ;;
        10) setup_auto_updates ;;
        11) install_lynis ;;
        12) setup_alert_script ;;
        13)
            install_sysmon
            install_glances
            install_ctop
            ;;
        14)
            install_sysmon
            install_glances
            install_netdata
            setup_logrotate
            setup_auto_updates
            setup_alert_script
            ;;
        0) return ;;
        *) print_error "Invalid choice."; return ;;
    esac
}

install_sysmon() {
    print_step "Installing system monitoring CLI tools..."
    if [[ "$PKG" == "apt" ]]; then
        pkg_install htop iotop sysstat nmon dstat ncdu
    else
        pkg_install htop iotop sysstat nmon ncdu 2>/dev/null || pkg_install htop sysstat ncdu
    fi
    print_success "Installed: htop, iotop, sysstat, nmon, ncdu"
    echo -e "  ${BOLD}Usage:${NC} htop (processes), iotop (disk I/O), nmon (all-in-one), ncdu (disk usage)"
}

install_glances() {
    print_step "Installing Glances (all-in-one monitor)..."
    if [[ "$PKG" == "apt" ]]; then
        pkg_install python3-pip
    else
        pkg_install python3-pip
    fi
    sudo pip3 install glances[all] 2>/dev/null || sudo pip3 install glances
    print_success "Glances installed."
    echo -e "  ${BOLD}Usage:${NC}"
    echo -e "    glances              (terminal UI)"
    echo -e "    glances -w           (web UI on port 61208)"
    echo -e "    glances --export csv (export to CSV)"
}

install_ctop() {
    print_step "Installing ctop (Docker container monitor)..."
    local arch
    arch=$(uname -m)
    case $arch in
        x86_64)  arch="amd64" ;;
        aarch64) arch="arm64" ;;
    esac
    sudo wget -q "https://github.com/bcicen/ctop/releases/download/v0.7.7/ctop-0.7.7-linux-${arch}" -O /usr/local/bin/ctop
    sudo chmod +x /usr/local/bin/ctop
    print_success "ctop installed."
    echo -e "  ${BOLD}Usage:${NC} ctop (requires Docker running)"
}

install_netdata() {
    print_step "Installing Netdata (real-time web dashboard)..."

    # Netdata provides a one-liner installer
    bash <(curl -Ss https://get.netdata.cloud/kickstart.sh) --dont-wait --no-updates 2>&1 || {
        # Fallback: manual install
        if [[ "$PKG" == "apt" ]]; then
            pkg_install netdata
        else
            pkg_install netdata 2>/dev/null || {
                print_error "Netdata install failed. Try manually: https://learn.netdata.cloud/docs/installing"
                return
            }
        fi
    }

    sudo systemctl enable netdata 2>/dev/null || true
    sudo systemctl start netdata 2>/dev/null || true

    print_success "Netdata installed and running."
    echo -e "  ${BOLD}Dashboard:${NC} http://$(curl -s --max-time 3 ifconfig.me 2>/dev/null || echo '<your-ip>'):19999"
    echo -e ""
    echo -e "  ${YELLOW}Note:${NC} Allow port 19999 in your security group / firewall."

    if confirm "  Open port 19999 in firewall now?"; then
        if [[ "$PKG" == "apt" ]]; then
            sudo ufw allow 19999/tcp 2>/dev/null || true
        else
            sudo firewall-cmd --permanent --add-port=19999/tcp 2>/dev/null || true
            sudo firewall-cmd --reload 2>/dev/null || true
        fi
        print_success "Port 19999 opened."
    fi
}

install_node_exporter() {
    print_step "Installing Prometheus Node Exporter..."

    local NE_VERSION="1.7.0"
    local arch
    arch=$(uname -m)
    case $arch in
        x86_64)  arch="amd64" ;;
        aarch64) arch="arm64" ;;
    esac

    cd /tmp
    wget -q "https://github.com/prometheus/node_exporter/releases/download/v${NE_VERSION}/node_exporter-${NE_VERSION}.linux-${arch}.tar.gz"
    tar xzf "node_exporter-${NE_VERSION}.linux-${arch}.tar.gz"
    sudo mv "node_exporter-${NE_VERSION}.linux-${arch}/node_exporter" /usr/local/bin/
    rm -rf "node_exporter-${NE_VERSION}.linux-${arch}"*
    cd - > /dev/null

    # Create systemd service
    sudo useradd --no-create-home --shell /bin/false node_exporter 2>/dev/null || true

    sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<'NESERVICE'
[Unit]
Description=Prometheus Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
NESERVICE

    sudo systemctl daemon-reload
    sudo systemctl enable node_exporter
    sudo systemctl start node_exporter

    print_success "Node Exporter running on port 9100."
    echo -e "  ${BOLD}Metrics:${NC} http://<your-ip>:9100/metrics"
    echo -e "  ${BOLD}Tip:${NC} Add this target to your Prometheus server's scrape config."
}

install_grafana() {
    print_step "Installing Grafana..."

    if [[ "$PKG" == "apt" ]]; then
        pkg_install apt-transport-https software-properties-common
        sudo mkdir -p /etc/apt/keyrings
        wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null
        echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
        sudo apt-get update -y
        pkg_install grafana
    else
        sudo tee /etc/yum.repos.d/grafana.repo > /dev/null <<'GRAFANAREPO'
[grafana]
name=grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
GRAFANAREPO
        pkg_install grafana
    fi

    sudo systemctl daemon-reload
    sudo systemctl enable grafana-server
    sudo systemctl start grafana-server

    print_success "Grafana installed and running on port 3000."
    echo -e "  ${BOLD}Dashboard:${NC} http://<your-ip>:3000"
    echo -e "  ${BOLD}Default login:${NC} admin / admin (change on first login)"
    echo -e ""

    if confirm "  Open port 3000 in firewall for Grafana?"; then
        if [[ "$PKG" == "apt" ]]; then
            sudo ufw allow 3000/tcp 2>/dev/null || true
        else
            sudo firewall-cmd --permanent --add-port=3000/tcp 2>/dev/null || true
            sudo firewall-cmd --reload 2>/dev/null || true
        fi
        print_success "Port 3000 opened."
    fi
}

install_goaccess() {
    print_step "Installing GoAccess (real-time log analyzer)..."
    if [[ "$PKG" == "apt" ]]; then
        pkg_install goaccess
    else
        pkg_install goaccess 2>/dev/null || {
            # Try EPEL
            sudo amazon-linux-extras install epel -y 2>/dev/null || true
            pkg_install goaccess
        }
    fi
    print_success "GoAccess installed."
    echo -e "  ${BOLD}Usage:${NC}"
    echo -e "    goaccess /var/log/nginx/access.log -c            (terminal)"
    echo -e "    goaccess /var/log/nginx/access.log -o report.html --real-time-html  (web report)"
}

setup_auto_updates() {
    print_step "Setting up automatic security updates..."
    if [[ "$PKG" == "apt" ]]; then
        pkg_install unattended-upgrades
        sudo dpkg-reconfigure -plow unattended-upgrades 2>/dev/null || {
            echo 'Unattended-Upgrade::Allowed-Origins { "${distro_id}:${distro_codename}-security"; };' | sudo tee /etc/apt/apt.conf.d/50unattended-upgrades > /dev/null
        }
    else
        pkg_install yum-cron
        sudo sed -i 's/apply_updates = no/apply_updates = yes/' /etc/yum/yum-cron.conf 2>/dev/null || true
        sudo systemctl enable yum-cron
        sudo systemctl start yum-cron
    fi
    print_success "Automatic security updates enabled."
}

install_cloudwatch() {
    print_step "Installing CloudWatch Agent..."
    if [[ "$PKG" == "apt" ]]; then
        wget -q https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb -O /tmp/cw-agent.deb
        sudo dpkg -i /tmp/cw-agent.deb
        rm -f /tmp/cw-agent.deb
    else
        sudo yum install -y amazon-cloudwatch-agent
    fi
    print_success "CloudWatch Agent installed."
    echo -e "  ${BOLD}Configure:${NC} sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-config-wizard"
    echo -e "  ${BOLD}Start:${NC}     sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json"
}

install_lynis() {
    print_step "Installing Lynis (security auditing tool)..."
    if [[ "$PKG" == "apt" ]]; then
        pkg_install lynis
    else
        pkg_install lynis 2>/dev/null || {
            sudo amazon-linux-extras install epel -y 2>/dev/null || true
            pkg_install lynis
        }
    fi
    print_success "Lynis installed."
    echo -e "  ${BOLD}Usage:${NC} sudo lynis audit system"
    echo -e "  This will scan your system and provide a hardening score + recommendations."

    if confirm "  Run a security audit now?"; then
        sudo lynis audit system --quick
    fi
}

setup_logrotate() {
    print_step "Configuring logrotate for app logs..."
    read -rp "  Enter log directory path [default: /var/log/app]: " log_dir
    log_dir=${log_dir:-/var/log/app}

    sudo mkdir -p "$log_dir"

    sudo tee /etc/logrotate.d/app-logs > /dev/null <<LOGCONF
${log_dir}/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    copytruncate
}
LOGCONF
    print_success "Logrotate configured for $log_dir (14 days, compressed)."
}

setup_alert_script() {
    print_step "Setting up system resource alert script..."

    read -rp "  CPU usage threshold % [default: 90]: " cpu_thresh
    cpu_thresh=${cpu_thresh:-90}
    read -rp "  Memory usage threshold % [default: 85]: " mem_thresh
    mem_thresh=${mem_thresh:-85}
    read -rp "  Disk usage threshold % [default: 80]: " disk_thresh
    disk_thresh=${disk_thresh:-80}

    local alert_script="/usr/local/bin/ec2-resource-alert.sh"
    local alert_log="/var/log/ec2-alerts.log"

    sudo tee "$alert_script" > /dev/null <<ALERTSCRIPT
#!/bin/bash
# EC2 Resource Alert Script
TIMESTAMP=\$(date '+%Y-%m-%d %H:%M:%S')
ALERT_LOG="${alert_log}"
HOSTNAME=\$(hostname)
ALERT=0

# CPU check
CPU_USAGE=\$(top -bn1 | grep "Cpu(s)" | awk '{print int(\$2 + \$4)}')
if [ "\$CPU_USAGE" -ge ${cpu_thresh} ]; then
    echo "[\$TIMESTAMP] ALERT: CPU usage is \${CPU_USAGE}% (threshold: ${cpu_thresh}%) on \$HOSTNAME" >> "\$ALERT_LOG"
    ALERT=1
fi

# Memory check
MEM_USAGE=\$(free | awk '/Mem:/ {printf "%.0f", \$3/\$2 * 100}')
if [ "\$MEM_USAGE" -ge ${mem_thresh} ]; then
    echo "[\$TIMESTAMP] ALERT: Memory usage is \${MEM_USAGE}% (threshold: ${mem_thresh}%) on \$HOSTNAME" >> "\$ALERT_LOG"
    ALERT=1
fi

# Disk check
DISK_USAGE=\$(df / | awk 'NR==2 {print int(\$5)}')
if [ "\$DISK_USAGE" -ge ${disk_thresh} ]; then
    echo "[\$TIMESTAMP] ALERT: Disk usage is \${DISK_USAGE}% (threshold: ${disk_thresh}%) on \$HOSTNAME" >> "\$ALERT_LOG"
    ALERT=1
fi

# Top 5 processes by memory (logged on any alert)
if [ "\$ALERT" -eq 1 ]; then
    echo "[\$TIMESTAMP] Top processes by memory:" >> "\$ALERT_LOG"
    ps aux --sort=-%mem | head -6 >> "\$ALERT_LOG"
    echo "---" >> "\$ALERT_LOG"
fi
ALERTSCRIPT

    sudo chmod +x "$alert_script"
    sudo touch "$alert_log"

    # Add cron job - run every 5 minutes
    (sudo crontab -l 2>/dev/null | grep -v "ec2-resource-alert"; echo "*/5 * * * * $alert_script") | sudo crontab -

    print_success "Alert script installed (runs every 5 min via cron)."
    echo -e "  ${BOLD}Thresholds:${NC} CPU=${cpu_thresh}%, Memory=${mem_thresh}%, Disk=${disk_thresh}%"
    echo -e "  ${BOLD}Alert log:${NC}  $alert_log"
    echo -e "  ${BOLD}Script:${NC}     $alert_script"
    echo -e ""

    if confirm "  Set up email notifications for alerts? (requires mailutils/sendmail)"; then
        if [[ "$PKG" == "apt" ]]; then
            pkg_install mailutils
        else
            pkg_install mailx
        fi

        read -rp "  Enter alert email address: " alert_email
        if [[ -n "$alert_email" ]]; then
            # Add email sending to the alert script
            sudo sed -i "/^fi$/a\\
\\n# Send email on alert\\nif [ \"\\\$ALERT\" -eq 1 ]; then\\n    tail -20 \"\\\$ALERT_LOG\" | mail -s \"EC2 Alert: \\\$HOSTNAME\" ${alert_email}\\nfi" "$alert_script"
            print_success "Email alerts configured -> $alert_email"
        fi
    fi
}

# ============================================================
#  GIT SETUP
# ============================================================
setup_git() {
    echo -e "\n${CYAN}── Git Configuration ──${NC}"

    read -rp "  Enter Git username: " git_name
    if [[ -n "$git_name" ]]; then
        git config --global user.name "$git_name"
    fi

    read -rp "  Enter Git email: " git_email
    if [[ -n "$git_email" ]]; then
        git config --global user.email "$git_email"
    fi

    git config --global init.defaultBranch main
    git config --global pull.rebase false

    if confirm "  Set up Git credential cache (15 min)?"; then
        git config --global credential.helper 'cache --timeout=900'
    fi

    if confirm "  Generate SSH key for Git (GitHub/GitLab)?"; then
        local key_email="${git_email:-$USER@$(hostname)}"
        read -rp "  Key type - 1) ed25519 (recommended) 2) rsa [default: 1]: " key_type
        key_type=${key_type:-1}

        if [[ "$key_type" == "1" ]]; then
            ssh-keygen -t ed25519 -C "$key_email" -f "$HOME/.ssh/id_ed25519" -N ""
            print_success "SSH key generated: $HOME/.ssh/id_ed25519.pub"
            echo -e "\n  ${BOLD}Your public key (add to GitHub/GitLab):${NC}"
            cat "$HOME/.ssh/id_ed25519.pub"
        else
            ssh-keygen -t rsa -b 4096 -C "$key_email" -f "$HOME/.ssh/id_rsa" -N ""
            print_success "SSH key generated: $HOME/.ssh/id_rsa.pub"
            echo -e "\n  ${BOLD}Your public key (add to GitHub/GitLab):${NC}"
            cat "$HOME/.ssh/id_rsa.pub"
        fi
    fi

    print_success "Git configured."
}

# ============================================================
#  BASHRC CUSTOMIZATION
# ============================================================
setup_bashrc() {
    echo -e "\n${CYAN}── .bashrc Customization ──${NC}"

    local bashrc="$HOME/.bashrc"
    local backup="$HOME/.bashrc.backup.$(date +%Y%m%d%H%M%S)"

    # Backup first
    cp "$bashrc" "$backup" 2>/dev/null || true
    print_success "Backup created: $backup"

    echo -e "\n  Select what to add/modify:"
    echo -e "    1) Add useful aliases"
    echo -e "    2) Customize PS1 prompt (colored, with git branch)"
    echo -e "    3) Add environment variables"
    echo -e "    4) Set default editor"
    echo -e "    5) Add PATH entries"
    echo -e "    6) Add custom command/line"
    echo -e "    7) Enable history improvements"
    echo -e "    8) Apply a full recommended preset"
    echo -e "    9) View current .bashrc"
    echo -e "   10) Back to main menu"
    read -rp "  Choice [1-10]: " bashrc_choice

    case $bashrc_choice in
        1) bashrc_aliases ;;
        2) bashrc_prompt ;;
        3) bashrc_env_vars ;;
        4) bashrc_editor ;;
        5) bashrc_path ;;
        6) bashrc_custom_line ;;
        7) bashrc_history ;;
        8) bashrc_full_preset ;;
        9)
            echo -e "\n${BOLD}--- Current .bashrc ---${NC}"
            cat "$bashrc"
            echo -e "${BOLD}--- End ---${NC}"
            ;;
        10) return ;;
        *) print_error "Invalid choice."; return ;;
    esac

    echo -e "\n  Run ${CYAN}source ~/.bashrc${NC} or open a new terminal to apply changes."
}

bashrc_aliases() {
    print_step "Adding useful aliases..."

    local bashrc="$HOME/.bashrc"
    local marker="# --- EC2 Setup: Aliases ---"

    # Don't add duplicates
    if grep -q "$marker" "$bashrc" 2>/dev/null; then
        print_warn "Aliases already added. Skipping."
        return
    fi

    cat >> "$bashrc" <<'ALIASES'

# --- EC2 Setup: Aliases ---
alias ll='ls -alFh --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias df='df -h'
alias du='du -sh'
alias free='free -h'
alias ports='sudo netstat -tlnp'
alias myip='curl -s ifconfig.me && echo'
alias reload='source ~/.bashrc'

# Docker aliases
alias dc='docker compose'
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dlog='docker logs -f'

# PM2 aliases
alias pm2l='pm2 list'
alias pm2log='pm2 logs'

# Systemd aliases
alias sc='sudo systemctl'
alias scr='sudo systemctl restart'
alias scs='sudo systemctl status'

# Nginx aliases
alias nginx-t='sudo nginx -t'
alias nginx-r='sudo nginx -t && sudo systemctl reload nginx'
ALIASES

    print_success "Aliases added to .bashrc"
    echo -e "  Added: ll, la, .., ..., ports, myip, reload, dc, dps, pm2l, sc, nginx-t, etc."
}

bashrc_prompt() {
    print_step "Customizing PS1 prompt..."

    local bashrc="$HOME/.bashrc"
    local marker="# --- EC2 Setup: PS1 Prompt ---"

    if grep -q "$marker" "$bashrc" 2>/dev/null; then
        print_warn "Custom prompt already added. Skipping."
        return
    fi

    echo -e "\n  Select prompt style:"
    echo -e "    1) Minimal: ${GREEN}user@host${NC}:${BLUE}~/dir${NC}\$ "
    echo -e "    2) With Git branch: ${GREEN}user@host${NC}:${BLUE}~/dir${NC} ${YELLOW}(main)${NC}\$ "
    echo -e "    3) Fancy multi-info: [time] user@host:dir (git) \$"
    read -rp "  Choice [1-3, default=2]: " prompt_style
    prompt_style=${prompt_style:-2}

    case $prompt_style in
        1)
            cat >> "$bashrc" <<'PROMPT1'

# --- EC2 Setup: PS1 Prompt ---
PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
PROMPT1
            ;;
        2)
            cat >> "$bashrc" <<'PROMPT2'

# --- EC2 Setup: PS1 Prompt ---
parse_git_branch() {
    git branch 2>/dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}
PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[33m\]$(parse_git_branch)\[\033[00m\]\$ '
PROMPT2
            ;;
        3)
            cat >> "$bashrc" <<'PROMPT3'

# --- EC2 Setup: PS1 Prompt ---
parse_git_branch() {
    git branch 2>/dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}
PS1='\[\033[0;90m\][\t]\[\033[00m\] \[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[33m\]$(parse_git_branch)\[\033[00m\]\n\$ '
PROMPT3
            ;;
    esac

    print_success "PS1 prompt customized."
}

bashrc_env_vars() {
    print_step "Adding environment variables..."

    local bashrc="$HOME/.bashrc"

    echo -e "  Enter environment variables one per line."
    echo -e "  Format: KEY=value"
    echo -e "  Type ${BOLD}done${NC} when finished.\n"

    while true; do
        read -rp "  > " env_line
        if [[ "$env_line" == "done" || -z "$env_line" ]]; then
            break
        fi
        # Validate format
        if [[ "$env_line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
            echo "export $env_line" >> "$bashrc"
            print_success "Added: export $env_line"
        else
            print_error "Invalid format. Use KEY=value"
        fi
    done
}

bashrc_editor() {
    print_step "Setting default editor..."

    echo -e "  Select editor:"
    echo -e "    1) vim"
    echo -e "    2) nano"
    echo -e "    3) Custom"
    read -rp "  Choice [1-3, default=1]: " editor_choice
    editor_choice=${editor_choice:-1}

    local editor
    case $editor_choice in
        1) editor="vim" ;;
        2) editor="nano" ;;
        3)
            read -rp "  Enter editor command: " editor
            ;;
    esac

    local bashrc="$HOME/.bashrc"
    echo "" >> "$bashrc"
    echo "# --- EC2 Setup: Default Editor ---" >> "$bashrc"
    echo "export EDITOR=$editor" >> "$bashrc"
    echo "export VISUAL=$editor" >> "$bashrc"

    print_success "Default editor set to: $editor"
}

bashrc_path() {
    print_step "Adding PATH entries..."

    local bashrc="$HOME/.bashrc"

    echo -e "  Enter directories to add to PATH."
    echo -e "  Type ${BOLD}done${NC} when finished.\n"

    while true; do
        read -rp "  Directory: " path_entry
        if [[ "$path_entry" == "done" || -z "$path_entry" ]]; then
            break
        fi
        echo "export PATH=\"$path_entry:\$PATH\"" >> "$bashrc"
        print_success "Added to PATH: $path_entry"
    done
}

bashrc_custom_line() {
    print_step "Adding custom line to .bashrc..."

    local bashrc="$HOME/.bashrc"

    echo -e "  Enter the line to add (it will be appended as-is):"
    read -rp "  > " custom_line

    if [[ -n "$custom_line" ]]; then
        echo "" >> "$bashrc"
        echo "$custom_line" >> "$bashrc"
        print_success "Added: $custom_line"
    fi
}

bashrc_history() {
    print_step "Improving bash history settings..."

    local bashrc="$HOME/.bashrc"
    local marker="# --- EC2 Setup: History ---"

    if grep -q "$marker" "$bashrc" 2>/dev/null; then
        print_warn "History settings already added. Skipping."
        return
    fi

    cat >> "$bashrc" <<'HISTORY'

# --- EC2 Setup: History ---
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth:erasedups
HISTTIMEFORMAT="%F %T  "
shopt -s histappend
PROMPT_COMMAND="history -a; $PROMPT_COMMAND"
HISTORY

    print_success "History improvements added (10k entries, timestamps, dedup, append mode)."
}

bashrc_full_preset() {
    print_step "Applying full recommended .bashrc preset..."
    bashrc_aliases
    bashrc_prompt
    bashrc_history
    bashrc_editor

    local bashrc="$HOME/.bashrc"
    local marker="# --- EC2 Setup: Misc ---"

    if ! grep -q "$marker" "$bashrc" 2>/dev/null; then
        cat >> "$bashrc" <<'MISC'

# --- EC2 Setup: Misc ---
# Auto-cd into directories
shopt -s autocd 2>/dev/null
# Correct minor typos in cd
shopt -s cdspell 2>/dev/null
# Case-insensitive globbing
shopt -s nocaseglob 2>/dev/null
# Better tab completion
bind 'set show-all-if-ambiguous on'
bind 'set completion-ignore-case on'

# Display system info on login
echo ""
echo -e "\033[1;36m$(hostname)\033[0m | $(uname -r) | $(date)"
echo -e "IP: $(curl -s --max-time 2 ifconfig.me 2>/dev/null || echo 'N/A') | Uptime:$(uptime -p 2>/dev/null || uptime)"
echo -e "Disk: $(df -h / | awk 'NR==2{print $3"/"$2" ("$5")"}') | RAM: $(free -h | awk 'NR==2{print $3"/"$2}')"
echo ""
MISC
    fi

    print_success "Full .bashrc preset applied."
}

# ============================================================
#  TIMEZONE & LOCALE
# ============================================================
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

# ============================================================
#  NODE.JS / PM2 / NGINX / DOCKER / PYTHON / CERTBOT / FIREWALL / SWAP
#  (same as before, kept intact)
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

# ============================================================
#  BACKEND SETUP
# ============================================================
setup_backend() {
    echo -e "\n${CYAN}── Backend Setup ──${NC}"

    echo -e "\n  Select backend runtime:"
    echo -e "    1) Node.js (Express / Fastify / NestJS etc.)"
    echo -e "    2) Python (Flask / FastAPI / Django etc.)"
    echo -e "    3) Docker (containerized app)"
    read -rp "  Choice [1-3]: " backend_runtime

    case $backend_runtime in
        1)
            install_node
            install_pm2
            ;;
        2)
            install_python
            ;;
        3)
            install_docker
            ;;
        *)
            print_error "Invalid choice."
            return
            ;;
    esac

    # Reverse proxy
    if confirm "  Set up Nginx as reverse proxy?"; then
        install_nginx

        read -rp "  Enter your app's port [default: 3000]: " app_port
        app_port=${app_port:-3000}

        read -rp "  Enter domain name (leave blank for IP-based access): " app_domain

        configure_nginx_backend "$app_port" "$app_domain"

        # SSL
        if [[ -n "$app_domain" ]]; then
            if confirm "  Set up SSL with Let's Encrypt?"; then
                install_certbot
                setup_ssl "$app_domain"
            fi
        fi
    fi

    # Firewall
    if confirm "  Configure firewall (allow SSH, HTTP, HTTPS)?"; then
        setup_firewall
    fi

    # Open custom port
    if [[ "$backend_runtime" != "3" ]]; then
        if confirm "  Open a custom port in firewall (e.g. for direct API access)?"; then
            read -rp "  Port number: " custom_port
            if [[ -n "$custom_port" ]]; then
                if [[ "$PKG" == "apt" ]]; then
                    sudo ufw allow "$custom_port/tcp"
                else
                    sudo firewall-cmd --permanent --add-port="${custom_port}/tcp" 2>/dev/null || true
                    sudo firewall-cmd --reload 2>/dev/null || true
                fi
                print_success "Port $custom_port opened."
            fi
        fi
    fi

    echo -e "\n${GREEN}── Backend setup complete! ──${NC}"

    if [[ "$backend_runtime" == "1" ]]; then
        echo -e "
  ${BOLD}Quick start:${NC}
    1. Clone/upload your project
    2. cd your-project && npm install
    3. pm2 start app.js --name my-app
    4. pm2 save
"
    elif [[ "$backend_runtime" == "2" ]]; then
        echo -e "
  ${BOLD}Quick start:${NC}
    1. Clone/upload your project
    2. python3 -m venv venv && source venv/bin/activate
    3. pip install -r requirements.txt
    4. Run with gunicorn / uvicorn
"
    elif [[ "$backend_runtime" == "3" ]]; then
        echo -e "
  ${BOLD}Quick start:${NC}
    1. Clone/upload your project
    2. docker compose up -d
"
    fi
}

# ============================================================
#  FRONTEND SETUP
# ============================================================
setup_frontend() {
    echo -e "\n${CYAN}── Frontend Setup ──${NC}"

    echo -e "\n  Select frontend type:"
    echo -e "    1) Static site (React / Vue / Angular build output)"
    echo -e "    2) SSR app (Next.js / Nuxt.js - runs as a server)"
    read -rp "  Choice [1-2]: " frontend_type

    case $frontend_type in
        1)
            install_nginx

            read -rp "  Enter web root directory [default: /var/www/html]: " web_root
            web_root=${web_root:-/var/www/html}

            read -rp "  Enter domain name (leave blank for IP-based access): " fe_domain
            configure_nginx_frontend "$web_root" "$fe_domain"

            if confirm "  Install Node.js (for building the frontend on server)?"; then
                install_node
            fi

            if [[ -n "$fe_domain" ]]; then
                if confirm "  Set up SSL with Let's Encrypt?"; then
                    install_certbot
                    setup_ssl "$fe_domain"
                fi
            fi
            ;;
        2)
            install_node
            install_pm2
            install_nginx

            read -rp "  Enter your SSR app's port [default: 3000]: " ssr_port
            ssr_port=${ssr_port:-3000}

            read -rp "  Enter domain name (leave blank for IP-based access): " ssr_domain
            configure_nginx_backend "$ssr_port" "$ssr_domain"

            if [[ -n "$ssr_domain" ]]; then
                if confirm "  Set up SSL with Let's Encrypt?"; then
                    install_certbot
                    setup_ssl "$ssr_domain"
                fi
            fi
            ;;
        *)
            print_error "Invalid choice."
            return
            ;;
    esac

    if confirm "  Configure firewall (allow SSH, HTTP, HTTPS)?"; then
        setup_firewall
    fi

    echo -e "\n${GREEN}── Frontend setup complete! ──${NC}"

    if [[ "$frontend_type" == "1" ]]; then
        echo -e "
  ${BOLD}Quick start:${NC}
    1. Build your project locally: npm run build
    2. Upload build output to: $web_root
       scp -r ./dist/* user@server:$web_root/
"
    else
        echo -e "
  ${BOLD}Quick start:${NC}
    1. Clone/upload your project
    2. cd your-project && npm install && npm run build
    3. pm2 start npm --name my-app -- start
    4. pm2 save
"
    fi
}

# ============================================================
#  FULL STACK SETUP
# ============================================================
setup_fullstack() {
    echo -e "\n${CYAN}── Full Stack Setup ──${NC}"
    echo -e "  This will set up both backend and frontend.\n"
    setup_backend
    echo ""
    setup_frontend
}

# ============================================================
#  MAIN MENU (loop-based)
# ============================================================
main() {
    print_banner
    detect_os

    # Initial system setup
    if confirm "Update system packages?"; then
        pkg_update
    fi

    if confirm "Set up swap file? (recommended for small instances)"; then
        setup_swap
    fi

    install_common

    # Loop menu so user can do multiple things
    while true; do
        echo -e "\n${BOLD}╔══════════════════════════════════════════╗${NC}"
        echo -e "${BOLD}║            Main Menu                     ║${NC}"
        echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}"
        echo -e "   1) Backend hosting setup"
        echo -e "   2) Frontend hosting setup"
        echo -e "   3) Full stack (Backend + Frontend)"
        echo -e "   4) SSH setup & hardening"
        echo -e "   5) Database setup"
        echo -e "   6) Git configuration"
        echo -e "   7) Customize .bashrc"
        echo -e "   8) Timezone & locale"
        echo -e "   9) Monitoring, logging & security tools"
        echo -e "  10) Firewall setup"
        echo -e "  11) Install Docker"
        echo -e "  12) Install Certbot (SSL)"
        echo -e "   0) Exit"
        echo -e ""
        read -rp "Choice [0-12]: " menu_choice

        case $menu_choice in
            1)  setup_backend ;;
            2)  setup_frontend ;;
            3)  setup_fullstack ;;
            4)  setup_ssh ;;
            5)  setup_database ;;
            6)  setup_git ;;
            7)  setup_bashrc ;;
            8)  setup_timezone ;;
            9)  setup_monitoring ;;
            10) setup_firewall ;;
            11) install_docker ;;
            12) install_certbot ;;
            0)
                echo -e "\n${GREEN}${BOLD}All done!${NC} Your EC2 instance is ready."
                echo -e "Run ${CYAN}source ~/.bashrc${NC} to apply shell changes."
                echo -e "Run ${CYAN}sudo reboot${NC} if needed for group/kernel changes.\n"
                exit 0
                ;;
            *)
                print_error "Invalid choice. Try again."
                ;;
        esac
    done
}

main
