#!/bin/bash

# ============================================================
#  instaserver - Server Snapshot Tool
#  https://github.com/harshith-km/instaserver
#
#  Takes a complete snapshot of your server's current state:
#  - OS & system info
#  - Installed packages & versions
#  - Running services
#  - Project directories with Git remotes
#  - Nginx/Apache configs
#  - Database info
#  - Cron jobs
#  - Environment variables & .env files
#  - SSH config
#  - Firewall rules
#  - Docker containers & images
#  - PM2 processes
#  - System resources
#
#  Usage:
#    bash <(curl -fsSL https://raw.githubusercontent.com/harshith-km/instaserver/main/snapshot.sh)
#
#  Output: ~/server-snapshot-YYYYMMDD-HHMMSS/
# ============================================================

set -e

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

step() { echo -e "\n${BLUE}[SCAN]${NC} ${BOLD}$1${NC}"; }
ok() { echo -e "${GREEN}  [OK]${NC} $1"; }
warn() { echo -e "${YELLOW}  [SKIP]${NC} $1"; }
info() { echo -e "${CYAN}  ->  ${NC} $1"; }

# --- Setup output directory ---
TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
SNAP_DIR="$HOME/server-snapshot-$TIMESTAMP"
mkdir -p "$SNAP_DIR"

echo -e "${CYAN}"
echo "╔══════════════════════════════════════════════════╗"
echo "║        instaserver - Server Snapshot             ║"
echo "╚══════════════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "Output: ${BOLD}$SNAP_DIR/${NC}"
echo ""

# ============================================================
#  1. OS & System Info
# ============================================================
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

# ============================================================
#  2. Installed Packages
# ============================================================
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

# ============================================================
#  3. Running Services
# ============================================================
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

# ============================================================
#  4. Project Directories & Git Repos
# ============================================================
step "Scanning project directories..."

SCAN_DIRS=("$HOME" "/var/www" "/opt" "/srv")

{
    echo "# ============================================================"
    echo "#  Project Directories & Git Repositories"
    echo "#  Scanned: ${SCAN_DIRS[*]}"
    echo "# ============================================================"
    echo ""

    for scan_dir in "${SCAN_DIRS[@]}"; do
        if [ ! -d "$scan_dir" ]; then
            continue
        fi

        echo "## $scan_dir"
        echo "---"

        # Find git repos (max depth 3 to avoid going too deep)
        while IFS= read -r git_dir; do
            repo_dir=$(dirname "$git_dir")
            rel_path="${repo_dir#$scan_dir/}"

            echo ""
            echo "### $rel_path"
            echo "  Path:   $repo_dir"

            # Git remote
            if [ -d "$git_dir" ]; then
                remote=$(git -C "$repo_dir" remote get-url origin 2>/dev/null || echo "no remote")
                branch=$(git -C "$repo_dir" branch --show-current 2>/dev/null || echo "unknown")
                last_commit=$(git -C "$repo_dir" log -1 --format="%h %s (%cr)" 2>/dev/null || echo "unknown")
                echo "  Remote: $remote"
                echo "  Branch: $branch"
                echo "  Last:   $last_commit"
            fi

            # Detect project type
            if [ -f "$repo_dir/package.json" ]; then
                pkg_name=$(grep -o '"name":[^,]*' "$repo_dir/package.json" 2>/dev/null | head -1 | cut -d'"' -f4)
                echo "  Type:   Node.js ($pkg_name)"
                # Check for common frameworks
                if [ -f "$repo_dir/next.config.js" ] || [ -f "$repo_dir/next.config.mjs" ] || [ -f "$repo_dir/next.config.ts" ]; then
                    echo "  Framework: Next.js"
                elif grep -q '"nuxt"' "$repo_dir/package.json" 2>/dev/null; then
                    echo "  Framework: Nuxt.js"
                elif grep -q '"react"' "$repo_dir/package.json" 2>/dev/null; then
                    echo "  Framework: React"
                elif grep -q '"vue"' "$repo_dir/package.json" 2>/dev/null; then
                    echo "  Framework: Vue.js"
                elif grep -q '"express"' "$repo_dir/package.json" 2>/dev/null; then
                    echo "  Framework: Express.js"
                elif grep -q '"fastify"' "$repo_dir/package.json" 2>/dev/null; then
                    echo "  Framework: Fastify"
                elif grep -q '"@nestjs/core"' "$repo_dir/package.json" 2>/dev/null; then
                    echo "  Framework: NestJS"
                fi
            elif [ -f "$repo_dir/requirements.txt" ]; then
                echo "  Type:   Python"
                if [ -f "$repo_dir/manage.py" ]; then
                    echo "  Framework: Django"
                elif grep -q "fastapi" "$repo_dir/requirements.txt" 2>/dev/null; then
                    echo "  Framework: FastAPI"
                elif grep -q "flask" "$repo_dir/requirements.txt" 2>/dev/null; then
                    echo "  Framework: Flask"
                fi
            elif [ -f "$repo_dir/Dockerfile" ] || [ -f "$repo_dir/docker-compose.yml" ] || [ -f "$repo_dir/compose.yml" ]; then
                echo "  Type:   Docker"
            elif [ -f "$repo_dir/go.mod" ]; then
                echo "  Type:   Go"
            elif [ -f "$repo_dir/Cargo.toml" ]; then
                echo "  Type:   Rust"
            elif [ -f "$repo_dir/Gemfile" ]; then
                echo "  Type:   Ruby"
            elif [ -f "$repo_dir/pom.xml" ] || [ -f "$repo_dir/build.gradle" ]; then
                echo "  Type:   Java"
            fi

        done < <(find "$scan_dir" -maxdepth 4 -name ".git" -type d 2>/dev/null)

        echo ""
    done

    # Also list non-git directories in /var/www
    if [ -d "/var/www" ]; then
        echo ""
        echo "## /var/www (all directories)"
        echo "---"
        for dir in /var/www/*/; do
            if [ -d "$dir" ]; then
                size=$(du -sh "$dir" 2>/dev/null | cut -f1)
                echo "  $dir ($size)"
            fi
        done
    fi

} > "$SNAP_DIR/projects.txt"

repo_count=$(grep -c "^### " "$SNAP_DIR/projects.txt" 2>/dev/null || echo "0")
ok "Found $repo_count git repositories"

# ============================================================
#  5. Directory Structure
# ============================================================
step "Directory structure..."

{
    echo "# ============================================================"
    echo "#  Directory Trees"
    echo "# ============================================================"

    for dir in "$HOME" "/var/www" "/opt" "/srv"; do
        if [ -d "$dir" ]; then
            echo ""
            echo "## $dir (depth 2)"
            echo "---"
            if command -v tree &>/dev/null; then
                tree -L 2 -d --noreport "$dir" 2>/dev/null || ls -la "$dir" 2>/dev/null
            else
                find "$dir" -maxdepth 2 -type d 2>/dev/null | head -50
            fi
        fi
    done
} > "$SNAP_DIR/directory-tree.txt"

ok "Directory trees saved"

# ============================================================
#  6. Nginx / Apache Configuration
# ============================================================
step "Web server configuration..."

mkdir -p "$SNAP_DIR/nginx" "$SNAP_DIR/apache"

# Nginx
if command -v nginx &>/dev/null; then
    # Main config
    cp /etc/nginx/nginx.conf "$SNAP_DIR/nginx/" 2>/dev/null || true

    # Sites
    if [ -d "/etc/nginx/sites-available" ]; then
        cp -r /etc/nginx/sites-available "$SNAP_DIR/nginx/" 2>/dev/null || true
    fi
    if [ -d "/etc/nginx/sites-enabled" ]; then
        # List enabled sites (resolve symlinks)
        ls -la /etc/nginx/sites-enabled/ > "$SNAP_DIR/nginx/sites-enabled-list.txt" 2>/dev/null || true
    fi
    if [ -d "/etc/nginx/conf.d" ]; then
        cp -r /etc/nginx/conf.d "$SNAP_DIR/nginx/" 2>/dev/null || true
    fi

    # Nginx test
    nginx -T > "$SNAP_DIR/nginx/full-config-dump.txt" 2>/dev/null || true

    ok "Nginx configs saved"
else
    warn "Nginx not found"
fi

# Apache
if command -v apache2 &>/dev/null || command -v httpd &>/dev/null; then
    cp -r /etc/apache2/sites-available "$SNAP_DIR/apache/" 2>/dev/null || true
    cp -r /etc/httpd/conf.d "$SNAP_DIR/apache/" 2>/dev/null || true
    ok "Apache configs saved"
else
    warn "Apache not found"
fi

# ============================================================
#  7. Database Information
# ============================================================
step "Database information..."

{
    echo "# ============================================================"
    echo "#  Database Information"
    echo "# ============================================================"
    echo ""

    # PostgreSQL
    if command -v psql &>/dev/null; then
        echo "## PostgreSQL"
        echo "  Version: $(psql --version 2>/dev/null)"
        echo "  Status:  $(systemctl is-active postgresql 2>/dev/null || echo 'unknown')"
        echo "  Databases:"
        sudo -u postgres psql -l --no-align 2>/dev/null | grep '|' | cut -d'|' -f1 | while read db; do
            echo "    - $db"
        done
        echo ""
    fi

    # MySQL/MariaDB
    if command -v mysql &>/dev/null; then
        echo "## MySQL / MariaDB"
        echo "  Version: $(mysql --version 2>/dev/null)"
        echo "  Status:  $(systemctl is-active mysql 2>/dev/null || systemctl is-active mariadb 2>/dev/null || echo 'unknown')"
        echo "  Databases:"
        mysql -e "SHOW DATABASES;" 2>/dev/null | tail -n +2 | while read db; do
            echo "    - $db"
        done
        echo ""
    fi

    # MongoDB
    if command -v mongosh &>/dev/null || command -v mongo &>/dev/null; then
        echo "## MongoDB"
        echo "  Version: $(mongod --version 2>/dev/null | head -1)"
        echo "  Status:  $(systemctl is-active mongod 2>/dev/null || echo 'unknown')"
        echo "  Databases:"
        mongosh --quiet --eval "db.adminCommand('listDatabases').databases.forEach(d => print('    - ' + d.name))" 2>/dev/null || \
        mongo --quiet --eval "db.adminCommand('listDatabases').databases.forEach(d => print('    - ' + d.name))" 2>/dev/null || \
        echo "    (could not list - auth required?)"
        echo ""
    fi

    # Redis
    if command -v redis-cli &>/dev/null; then
        echo "## Redis"
        echo "  Version: $(redis-server --version 2>/dev/null)"
        echo "  Status:  $(systemctl is-active redis 2>/dev/null || systemctl is-active redis-server 2>/dev/null || echo 'unknown')"
        db_size=$(redis-cli DBSIZE 2>/dev/null || echo "N/A")
        echo "  DB Size: $db_size"
        echo ""
    fi

} > "$SNAP_DIR/databases.txt"

ok "Database info saved"

# ============================================================
#  8. Docker State
# ============================================================
step "Docker state..."

if command -v docker &>/dev/null; then
    {
        echo "# ============================================================"
        echo "#  Docker State"
        echo "# ============================================================"
        echo ""

        echo "## Running Containers"
        docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "  (none or permission denied)"

        echo ""
        echo "## All Containers"
        docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" 2>/dev/null || true

        echo ""
        echo "## Images"
        docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" 2>/dev/null || true

        echo ""
        echo "## Volumes"
        docker volume ls 2>/dev/null || true

        echo ""
        echo "## Networks"
        docker network ls 2>/dev/null || true

    } > "$SNAP_DIR/docker.txt"

    # Docker compose files
    mkdir -p "$SNAP_DIR/docker-compose"
    find "$HOME" /var/www /opt /srv -maxdepth 4 \( -name "docker-compose.yml" -o -name "docker-compose.yaml" -o -name "compose.yml" -o -name "compose.yaml" \) 2>/dev/null | while read f; do
        dest_name=$(echo "$f" | sed 's|/|__|g')
        cp "$f" "$SNAP_DIR/docker-compose/$dest_name" 2>/dev/null || true
    done

    ok "Docker state saved"
else
    warn "Docker not found"
fi

# ============================================================
#  9. PM2 Processes
# ============================================================
step "PM2 processes..."

if command -v pm2 &>/dev/null; then
    {
        echo "# ============================================================"
        echo "#  PM2 Processes"
        echo "# ============================================================"
        echo ""
        pm2 list 2>/dev/null || echo "No PM2 processes"
        echo ""
        echo "## PM2 Process Details (JSON)"
        pm2 jlist 2>/dev/null || true
    } > "$SNAP_DIR/pm2.txt"

    # Save PM2 ecosystem file if exists
    pm2 save 2>/dev/null || true
    if [ -f "$HOME/.pm2/dump.pm2" ]; then
        cp "$HOME/.pm2/dump.pm2" "$SNAP_DIR/pm2-dump.json" 2>/dev/null || true
    fi

    ok "PM2 process list saved"
else
    warn "PM2 not found"
fi

# ============================================================
#  10. Cron Jobs
# ============================================================
step "Cron jobs..."

{
    echo "# ============================================================"
    echo "#  Cron Jobs"
    echo "# ============================================================"
    echo ""

    echo "## User crontab ($USER)"
    crontab -l 2>/dev/null || echo "  (no crontab)"

    echo ""
    echo "## Root crontab"
    sudo crontab -l 2>/dev/null || echo "  (no crontab or no sudo)"

    echo ""
    echo "## /etc/cron.d/"
    ls -la /etc/cron.d/ 2>/dev/null || echo "  (empty)"

    echo ""
    echo "## System cron directories"
    for d in /etc/cron.daily /etc/cron.hourly /etc/cron.weekly /etc/cron.monthly; do
        if [ -d "$d" ]; then
            echo "  $d: $(ls "$d" 2>/dev/null | wc -l) scripts"
        fi
    done

} > "$SNAP_DIR/cron.txt"

ok "Cron jobs saved"

# ============================================================
#  11. SSH Configuration
# ============================================================
step "SSH configuration..."

{
    echo "# ============================================================"
    echo "#  SSH Configuration"
    echo "# ============================================================"
    echo ""

    echo "## sshd_config (key settings)"
    for setting in Port PermitRootLogin PasswordAuthentication PubkeyAuthentication ClientAliveInterval MaxAuthTries; do
        val=$(grep -i "^$setting" /etc/ssh/sshd_config 2>/dev/null || echo "$setting: (default)")
        echo "  $val"
    done

    echo ""
    echo "## Authorized Keys"
    if [ -f "$HOME/.ssh/authorized_keys" ]; then
        count=$(wc -l < "$HOME/.ssh/authorized_keys")
        echo "  $count key(s) in $HOME/.ssh/authorized_keys"
        # Show key fingerprints (not the actual keys)
        while read -r key; do
            if [ -n "$key" ] && [[ ! "$key" =~ ^# ]]; then
                fp=$(echo "$key" | ssh-keygen -lf - 2>/dev/null || echo "  (could not read fingerprint)")
                echo "  $fp"
            fi
        done < "$HOME/.ssh/authorized_keys"
    else
        echo "  (no authorized_keys file)"
    fi

    echo ""
    echo "## SSH Keys in ~/.ssh/"
    ls -la "$HOME/.ssh/" 2>/dev/null | grep -v authorized_keys | grep -v known_hosts || echo "  (empty)"

} > "$SNAP_DIR/ssh.txt"

ok "SSH config saved"

# ============================================================
#  12. Firewall Rules
# ============================================================
step "Firewall rules..."

{
    echo "# ============================================================"
    echo "#  Firewall Rules"
    echo "# ============================================================"
    echo ""

    if command -v ufw &>/dev/null; then
        echo "## UFW Status"
        sudo ufw status verbose 2>/dev/null || echo "  (could not read)"
    fi

    if command -v firewall-cmd &>/dev/null; then
        echo "## firewalld"
        sudo firewall-cmd --list-all 2>/dev/null || echo "  (could not read)"
    fi

    echo ""
    echo "## iptables"
    sudo iptables -L -n --line-numbers 2>/dev/null | head -50 || echo "  (could not read)"

} > "$SNAP_DIR/firewall.txt"

ok "Firewall rules saved"

# ============================================================
#  13. Environment Files
# ============================================================
step "Environment files (paths only, no secrets)..."

{
    echo "# ============================================================"
    echo "#  Environment Files Found"
    echo "#  NOTE: Contents are NOT included for security"
    echo "# ============================================================"
    echo ""

    echo "## .env files"
    find "$HOME" /var/www /opt /srv -maxdepth 4 -name ".env" -o -name ".env.*" 2>/dev/null | while read f; do
        size=$(stat -c%s "$f" 2>/dev/null || stat -f%z "$f" 2>/dev/null || echo "?")
        vars=$(grep -c "=" "$f" 2>/dev/null || echo "?")
        echo "  $f ($vars variables, ${size}B)"
        # Show ONLY the key names, not values
        echo "    Keys: $(grep -oP '^[A-Za-z_][A-Za-z0-9_]*(?==)' "$f" 2>/dev/null | tr '\n' ', ' || echo 'could not parse')"
    done

    echo ""
    echo "## Systemd environment files"
    find /etc/systemd/system -name "*.service" -exec grep -l "EnvironmentFile" {} \; 2>/dev/null | while read f; do
        env_file=$(grep "EnvironmentFile" "$f" 2>/dev/null | head -1)
        echo "  $f -> $env_file"
    done

} > "$SNAP_DIR/env-files.txt"

ok "Environment file locations saved (no secrets included)"

# ============================================================
#  14. Systemd Custom Services
# ============================================================
step "Custom systemd services..."

mkdir -p "$SNAP_DIR/systemd"

# Copy user-created service files
for svc_dir in /etc/systemd/system /etc/systemd/system/*.wants; do
    if [ -d "$svc_dir" ]; then
        find "$svc_dir" -maxdepth 1 -name "*.service" -type f 2>/dev/null | while read f; do
            # Skip symlinks (those are just enabled built-in services)
            if [ ! -L "$f" ]; then
                cp "$f" "$SNAP_DIR/systemd/" 2>/dev/null || true
            fi
        done
    fi
done

svc_count=$(ls "$SNAP_DIR/systemd/" 2>/dev/null | wc -l)
ok "Saved $svc_count custom service files"

# ============================================================
#  15. SSL Certificates
# ============================================================
step "SSL certificates..."

{
    echo "# ============================================================"
    echo "#  SSL Certificates"
    echo "# ============================================================"
    echo ""

    if [ -d "/etc/letsencrypt/live" ]; then
        echo "## Let's Encrypt Certificates"
        for cert_dir in /etc/letsencrypt/live/*/; do
            domain=$(basename "$cert_dir")
            if [ "$domain" != "README" ]; then
                expiry=$(openssl x509 -enddate -noout -in "$cert_dir/fullchain.pem" 2>/dev/null | cut -d= -f2)
                echo "  $domain (expires: $expiry)"
            fi
        done
    else
        echo "  No Let's Encrypt certificates found"
    fi

    echo ""
    echo "## Certbot renewal config"
    ls /etc/letsencrypt/renewal/ 2>/dev/null || echo "  (none)"

} > "$SNAP_DIR/ssl.txt"

ok "SSL info saved"

# ============================================================
#  16. Generate Reinstall Script
# ============================================================
step "Generating reinstall script..."

{
    cat <<'REINSTALL_HEADER'
#!/bin/bash
set -e

# ============================================================
#  instaserver - Auto-generated Reinstall Script
#  Recreates the server state from a snapshot
#
#  Review this script before running!
#  Some steps may need manual adjustment.
# ============================================================

GREEN='\033[0;32m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

step() { echo -e "\n${BLUE}[STEP]${NC} ${BOLD}$1${NC}"; }
ok() { echo -e "${GREEN}[OK]${NC} $1"; }

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ "$ID" == "ubuntu" || "$ID" == "debian" ]]; then
        PKG="apt"
    else
        PKG="yum"
    fi
fi

pkg_install() {
    if [[ "$PKG" == "apt" ]]; then
        sudo apt-get install -y "$@"
    else
        sudo yum install -y "$@"
    fi
}

step "Updating system..."
if [[ "$PKG" == "apt" ]]; then
    sudo apt-get update -y && sudo apt-get upgrade -y
else
    sudo yum update -y
fi
ok "System updated."

REINSTALL_HEADER

    # Node.js
    if command -v node &>/dev/null; then
        node_ver=$(node -v | grep -oP '\d+' | head -1)
        echo ""
        echo "# --- Node.js $node_ver ---"
        echo "step \"Installing Node.js $node_ver...\""
        echo "if [[ \"\$PKG\" == \"apt\" ]]; then"
        echo "    curl -fsSL \"https://deb.nodesource.com/setup_${node_ver}.x\" | sudo -E bash -"
        echo "    sudo apt-get install -y nodejs"
        echo "else"
        echo "    curl -fsSL \"https://rpm.nodesource.com/setup_${node_ver}.x\" | sudo bash -"
        echo "    sudo yum install -y nodejs"
        echo "fi"
        echo "sudo npm install -g npm@latest"
        echo 'ok "Node.js installed."'
    fi

    # PM2
    if command -v pm2 &>/dev/null; then
        echo ""
        echo "# --- PM2 ---"
        echo "step \"Installing PM2...\""
        echo "sudo npm install -g pm2"
        echo 'ok "PM2 installed."'
    fi

    # Nginx
    if command -v nginx &>/dev/null; then
        echo ""
        echo "# --- Nginx ---"
        echo "step \"Installing Nginx...\""
        echo "if [[ \"\$PKG\" == \"apt\" ]]; then"
        echo "    pkg_install nginx"
        echo "else"
        echo "    sudo amazon-linux-extras install nginx1 2>/dev/null || pkg_install nginx"
        echo "fi"
        echo "sudo systemctl enable nginx && sudo systemctl start nginx"
        echo 'ok "Nginx installed."'
    fi

    # Docker
    if command -v docker &>/dev/null; then
        echo ""
        echo "# --- Docker ---"
        echo "step \"Installing Docker...\""
        echo "if [[ \"\$PKG\" == \"apt\" ]]; then"
        echo "    curl -fsSL https://get.docker.com | sudo sh"
        echo "else"
        echo "    sudo yum install -y docker && sudo systemctl enable docker && sudo systemctl start docker"
        echo "fi"
        echo "sudo usermod -aG docker \"\$USER\""
        echo 'ok "Docker installed."'
    fi

    # Databases
    if command -v psql &>/dev/null; then
        echo ""
        echo "# --- PostgreSQL ---"
        echo "step \"Installing PostgreSQL...\""
        echo "if [[ \"\$PKG\" == \"apt\" ]]; then pkg_install postgresql postgresql-contrib; else pkg_install postgresql-server postgresql; fi"
        echo "sudo systemctl enable postgresql && sudo systemctl start postgresql"
        echo 'ok "PostgreSQL installed."'
    fi

    if command -v mysql &>/dev/null; then
        echo ""
        echo "# --- MySQL ---"
        echo "step \"Installing MySQL...\""
        echo "if [[ \"\$PKG\" == \"apt\" ]]; then pkg_install mysql-server; else pkg_install mariadb-server mariadb; fi"
        echo "sudo systemctl enable mysql 2>/dev/null || sudo systemctl enable mariadb 2>/dev/null"
        echo 'ok "MySQL installed."'
    fi

    if command -v mongod &>/dev/null; then
        echo ""
        echo "# --- MongoDB ---"
        echo "step \"Installing MongoDB...\""
        echo "echo '# Add MongoDB repo and install - see snapshot/databases.txt for version'"
        echo 'ok "MongoDB - manual setup required."'
    fi

    if command -v redis-cli &>/dev/null; then
        echo ""
        echo "# --- Redis ---"
        echo "step \"Installing Redis...\""
        echo "if [[ \"\$PKG\" == \"apt\" ]]; then pkg_install redis-server; else pkg_install redis; fi"
        echo "sudo systemctl enable redis-server 2>/dev/null || sudo systemctl enable redis 2>/dev/null"
        echo 'ok "Redis installed."'
    fi

    # Git repos
    echo ""
    echo "# --- Clone Projects ---"
    grep -A1 "Remote:" "$SNAP_DIR/projects.txt" 2>/dev/null | grep -v "^--$" | while IFS= read -r line; do
        if [[ "$line" == *"Path:"* ]]; then
            path=$(echo "$line" | sed 's/.*Path: *//')
        elif [[ "$line" == *"Remote:"* ]]; then
            remote=$(echo "$line" | sed 's/.*Remote: *//')
            if [[ "$remote" != "no remote" && -n "$remote" && -n "$path" ]]; then
                echo "step \"Cloning $remote...\""
                echo "mkdir -p \"$(dirname "$path")\""
                echo "git clone \"$remote\" \"$path\" 2>/dev/null || echo 'Already exists or failed'"
                echo "ok \"Cloned to $path\""
            fi
        fi
    done

    echo ""
    echo "# ============================================================"
    echo 'echo -e "\n${GREEN}${BOLD}Reinstall complete!${NC}"'
    echo 'echo "Review the snapshot directory for Nginx configs, .env files, and cron jobs to restore manually."'

} > "$SNAP_DIR/reinstall.sh"

chmod +x "$SNAP_DIR/reinstall.sh"
ok "Reinstall script generated"

# ============================================================
#  Summary
# ============================================================

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║        Snapshot Complete!                        ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}Location:${NC}  $SNAP_DIR/"
echo ""

# List files with sizes
total_size=$(du -sh "$SNAP_DIR" 2>/dev/null | cut -f1)
echo -e "  ${BOLD}Files:${NC}"
for f in "$SNAP_DIR"/*; do
    if [ -f "$f" ]; then
        fname=$(basename "$f")
        fsize=$(du -sh "$f" 2>/dev/null | cut -f1)
        echo -e "    $fname  ${CYAN}($fsize)${NC}"
    fi
done
for d in "$SNAP_DIR"/*/; do
    if [ -d "$d" ]; then
        dname=$(basename "$d")
        dsize=$(du -sh "$d" 2>/dev/null | cut -f1)
        echo -e "    $dname/  ${CYAN}($dsize)${NC}"
    fi
done

echo ""
echo -e "  ${BOLD}Total:${NC} $total_size"
echo ""
echo -e "  ${BOLD}To replicate this server:${NC}"
echo -e "    1. Copy the snapshot to the new instance"
echo -e "    2. Review ${CYAN}reinstall.sh${NC} and adjust as needed"
echo -e "    3. Run: ${CYAN}bash reinstall.sh${NC}"
echo -e "    4. Restore Nginx configs from ${CYAN}nginx/${NC}"
echo -e "    5. Restore cron jobs from ${CYAN}cron.txt${NC}"
echo -e "    6. Recreate .env files from ${CYAN}env-files.txt${NC}"
echo ""
