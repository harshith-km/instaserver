#!/bin/bash
# ============================================================
#  Monitoring, Logging & Security
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

    bash <(curl -Ss https://get.netdata.cloud/kickstart.sh) --dont-wait --no-updates 2>&1 || {
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
            sudo sed -i "/^fi$/a\\
\\n# Send email on alert\\nif [ \"\\\$ALERT\" -eq 1 ]; then\\n    tail -20 \"\\\$ALERT_LOG\" | mail -s \"EC2 Alert: \\\$HOSTNAME\" ${alert_email}\\nfi" "$alert_script"
            print_success "Email alerts configured -> $alert_email"
        fi
    fi
}
