#!/bin/bash
# Snapshot Module: System information, packages, services
# Sourced by snapshot.sh - expects SNAP_DIR, step(), ok(), warn(), info()

# ============================================================
#  1. OS & System Info
# ============================================================
snap_system_info() {
    step "System information..."

    cat > "$SNAP_DIR/system-info.txt" <<SYSEOF
# ============================================================
#  System Information
#  Captured: $(date)
# ============================================================

Hostname:       $(hostname)
OS:             $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2)
Kernel:         $(uname -r)
Architecture:   $(uname -m)
Uptime:         $(uptime -p 2>/dev/null || uptime)
Public IP:      $(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "N/A")
Private IP:     $(hostname -I 2>/dev/null | awk '{print $1}')
CPU:            $(grep -c ^processor /proc/cpuinfo 2>/dev/null || echo "N/A") cores - $(grep 'model name' /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | xargs || echo "N/A")
Total RAM:      $(free -h 2>/dev/null | awk '/Mem:/ {print $2}' || echo "N/A")
Total Disk:     $(df -h / 2>/dev/null | awk 'NR==2 {print $2}' || echo "N/A")
Used Disk:      $(df -h / 2>/dev/null | awk 'NR==2 {print $3 " (" $5 ")"}' || echo "N/A")
Swap:           $(free -h 2>/dev/null | awk '/Swap:/ {print $2}' || echo "N/A")
Timezone:       $(timedatectl show --property=Timezone --value 2>/dev/null || cat /etc/timezone 2>/dev/null || echo "N/A")
Default Shell:  $SHELL
SYSEOF

    ok "System info saved"
}

# ============================================================
#  2. Installed Packages
# ============================================================
snap_packages() {
    step "Installed packages..."

    {
        echo "# ============================================================"
        echo "#  Installed Packages"
        echo "# ============================================================"
        echo ""

        # Package manager packages
        if command -v dpkg &>/dev/null; then
            echo "## APT Packages ($(dpkg -l 2>/dev/null | grep ^ii | wc -l) total)"
            echo "---"
            dpkg -l 2>/dev/null | grep ^ii | awk '{print $2 "\t" $3}' || true
        elif command -v rpm &>/dev/null; then
            echo "## YUM/RPM Packages ($(rpm -qa 2>/dev/null | wc -l) total)"
            echo "---"
            rpm -qa --qf '%{NAME}\t%{VERSION}-%{RELEASE}\n' 2>/dev/null | sort || true
        fi
    } > "$SNAP_DIR/packages-all.txt"

    # Key software versions
    {
        echo "# ============================================================"
        echo "#  Key Software Versions"
        echo "# ============================================================"
        echo ""

        for cmd_check in \
            "node:node -v" \
            "npm:npm -v" \
            "python3:python3 --version" \
            "pip3:pip3 --version" \
            "docker:docker --version" \
            "docker-compose:docker compose version" \
            "nginx:nginx -v 2>&1" \
            "git:git --version" \
            "pm2:pm2 -v" \
            "aws:aws --version" \
            "certbot:certbot --version 2>&1" \
            "psql:psql --version" \
            "mysql:mysql --version 2>/dev/null || mysqld --version 2>/dev/null" \
            "mongod:mongod --version 2>/dev/null | head -1" \
            "redis-server:redis-server --version" \
            "go:go version" \
            "java:java -version 2>&1 | head -1" \
            "ruby:ruby --version" \
            "php:php --version 2>/dev/null | head -1" \
            "cargo:cargo --version" \
            "rustc:rustc --version" \
        ; do
            name="${cmd_check%%:*}"
            cmd="${cmd_check#*:}"
            if command -v "$name" &>/dev/null; then
                version=$(eval "$cmd" 2>/dev/null || echo "installed (version unknown)")
                echo "$name: $version"
            fi
        done
    } > "$SNAP_DIR/versions.txt"

    ok "Package lists saved ($(wc -l < "$SNAP_DIR/versions.txt") key tools found)"
}

# ============================================================
#  3. Running Services
# ============================================================
snap_services() {
    step "Running services..."

    {
        echo "# ============================================================"
        echo "#  Active Systemd Services"
        echo "# ============================================================"
        echo ""
        systemctl list-units --type=service --state=running --no-pager 2>/dev/null || echo "systemctl not available"
    } > "$SNAP_DIR/services.txt"

    # Listening ports
    {
        echo "# ============================================================"
        echo "#  Listening Ports"
        echo "# ============================================================"
        echo ""
        ss -tlnp 2>/dev/null || netstat -tlnp 2>/dev/null || echo "Neither ss nor netstat available"
    } > "$SNAP_DIR/ports.txt"

    ok "Services and ports saved"
}
