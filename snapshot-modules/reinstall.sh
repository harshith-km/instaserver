#!/bin/bash
# Snapshot Module: Reinstall Script Generator
# Sourced by snapshot.sh — expects: SNAP_DIR, step(), ok(), warn(), info(), color variables

snap_generate_reinstall() {
    step "Generating reinstall script..."

    local out="$SNAP_DIR/reinstall.sh"

    # ================================================================
    #  Header: shebang, set -e, colors, helpers, OS detection
    # ================================================================
    cat > "$out" <<'HEADER'
#!/bin/bash
set -e

# ============================================================
#  instaserver — Auto-generated Reinstall Script
#  Recreates the server state from a snapshot.
#
#  Review this script before running!
#  Some steps may need manual adjustment.
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

step()  { echo -e "\n${BLUE}[STEP]${NC} ${BOLD}$1${NC}"; }
ok()    { echo -e "${GREEN}  [OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}  [WARN]${NC} $1"; }
info()  { echo -e "${CYAN}  ->  ${NC} $1"; }

INSTALLED=()

# --- OS detection ---
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID="$ID"
    OS_VERSION="$VERSION_ID"
else
    OS_ID="unknown"
    OS_VERSION=""
fi

if [[ "$OS_ID" == "ubuntu" || "$OS_ID" == "debian" ]]; then
    PKG="apt"
elif [[ "$OS_ID" == "amzn" || "$OS_ID" == "centos" || "$OS_ID" == "rhel" || "$OS_ID" == "fedora" ]]; then
    PKG="yum"
else
    PKG="apt"
    warn "Unknown OS ($OS_ID) — defaulting to apt"
fi

pkg_install() {
    if [[ "$PKG" == "apt" ]]; then
        sudo apt-get install -y "$@"
    else
        sudo yum install -y "$@"
    fi
}

# ============================================================
#  System Update
# ============================================================
step "Updating system packages..."
if [[ "$PKG" == "apt" ]]; then
    sudo apt-get update -y && sudo apt-get upgrade -y
else
    sudo yum update -y
fi
ok "System updated"

HEADER

    # ================================================================
    #  Tool install blocks — only emitted when the tool is present
    # ================================================================

    # --- Node.js ---
    if command -v node &>/dev/null; then
        local node_major
        node_major=$(node -v 2>/dev/null | grep -oP '\d+' | head -1)
        cat >> "$out" <<NODE
# ============================================================
#  Node.js ${node_major}
# ============================================================
step "Installing Node.js ${node_major}..."
if [[ "\$PKG" == "apt" ]]; then
    curl -fsSL "https://deb.nodesource.com/setup_${node_major}.x" | sudo -E bash -
    sudo apt-get install -y nodejs
else
    curl -fsSL "https://rpm.nodesource.com/setup_${node_major}.x" | sudo bash -
    sudo yum install -y nodejs
fi
sudo npm install -g npm@latest
INSTALLED+=("Node.js ${node_major}")
ok "Node.js installed"

NODE
    fi

    # --- PM2 ---
    if command -v pm2 &>/dev/null; then
        cat >> "$out" <<'PM2'
# ============================================================
#  PM2
# ============================================================
step "Installing PM2..."
sudo npm install -g pm2
pm2 startup 2>/dev/null || true
INSTALLED+=("PM2")
ok "PM2 installed"

PM2
    fi

    # --- Nginx ---
    if command -v nginx &>/dev/null; then
        cat >> "$out" <<'NGINX'
# ============================================================
#  Nginx
# ============================================================
step "Installing Nginx..."
if [[ "$PKG" == "apt" ]]; then
    pkg_install nginx
else
    sudo amazon-linux-extras install nginx1 2>/dev/null || pkg_install nginx
fi
sudo systemctl enable nginx
sudo systemctl start nginx
INSTALLED+=("Nginx")
ok "Nginx installed"

NGINX
    fi

    # --- Docker ---
    if command -v docker &>/dev/null; then
        cat >> "$out" <<'DOCKER'
# ============================================================
#  Docker
# ============================================================
step "Installing Docker..."
if [[ "$PKG" == "apt" ]]; then
    curl -fsSL https://get.docker.com | sudo sh
else
    sudo yum install -y docker
    sudo systemctl enable docker
    sudo systemctl start docker
fi
sudo usermod -aG docker "$USER"
INSTALLED+=("Docker")
ok "Docker installed"

DOCKER
    fi

    # --- PostgreSQL ---
    if command -v psql &>/dev/null; then
        cat >> "$out" <<'POSTGRES'
# ============================================================
#  PostgreSQL
# ============================================================
step "Installing PostgreSQL..."
if [[ "$PKG" == "apt" ]]; then
    pkg_install postgresql postgresql-contrib
else
    pkg_install postgresql-server postgresql
    sudo postgresql-setup --initdb 2>/dev/null || true
fi
sudo systemctl enable postgresql
sudo systemctl start postgresql
INSTALLED+=("PostgreSQL")
ok "PostgreSQL installed"

POSTGRES
    fi

    # --- MySQL ---
    if command -v mysql &>/dev/null; then
        cat >> "$out" <<'MYSQL'
# ============================================================
#  MySQL / MariaDB
# ============================================================
step "Installing MySQL..."
if [[ "$PKG" == "apt" ]]; then
    pkg_install mysql-server
else
    pkg_install mariadb-server mariadb
fi
sudo systemctl enable mysql 2>/dev/null || sudo systemctl enable mariadb 2>/dev/null || true
sudo systemctl start mysql 2>/dev/null || sudo systemctl start mariadb 2>/dev/null || true
INSTALLED+=("MySQL")
ok "MySQL installed"

MYSQL
    fi

    # --- MongoDB ---
    if command -v mongod &>/dev/null || command -v mongosh &>/dev/null; then
        cat >> "$out" <<'MONGO'
# ============================================================
#  MongoDB
# ============================================================
step "Installing MongoDB..."
# MongoDB requires adding the official repo — see snapshot/databases.txt for version.
# Ubuntu/Debian example (adjust version as needed):
#   curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | sudo gpg --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg
#   echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/7.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list
#   sudo apt-get update && sudo apt-get install -y mongodb-org
warn "MongoDB requires manual repo setup — review and uncomment the commands above"
INSTALLED+=("MongoDB (manual)")
ok "MongoDB section done"

MONGO
    fi

    # --- Redis ---
    if command -v redis-cli &>/dev/null; then
        cat >> "$out" <<'REDIS'
# ============================================================
#  Redis
# ============================================================
step "Installing Redis..."
if [[ "$PKG" == "apt" ]]; then
    pkg_install redis-server
else
    pkg_install redis
fi
sudo systemctl enable redis-server 2>/dev/null || sudo systemctl enable redis 2>/dev/null || true
sudo systemctl start redis-server 2>/dev/null || sudo systemctl start redis 2>/dev/null || true
INSTALLED+=("Redis")
ok "Redis installed"

REDIS
    fi

    # --- AWS CLI ---
    if command -v aws &>/dev/null; then
        cat >> "$out" <<'AWSCLI'
# ============================================================
#  AWS CLI
# ============================================================
step "Installing AWS CLI..."
if ! command -v aws &>/dev/null; then
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
    cd /tmp && unzip -qo awscliv2.zip && sudo ./aws/install && rm -rf aws awscliv2.zip
    cd -
fi
INSTALLED+=("AWS CLI")
ok "AWS CLI installed"

AWSCLI
    fi

    # --- Certbot ---
    if command -v certbot &>/dev/null; then
        cat >> "$out" <<'CERTBOT'
# ============================================================
#  Certbot
# ============================================================
step "Installing Certbot..."
if [[ "$PKG" == "apt" ]]; then
    pkg_install certbot
    # Install plugin for your web server:
    # pkg_install python3-certbot-nginx
    # pkg_install python3-certbot-apache
else
    pkg_install certbot
fi
INSTALLED+=("Certbot")
ok "Certbot installed"

CERTBOT
    fi

    # --- Fail2ban ---
    if command -v fail2ban-client &>/dev/null; then
        cat >> "$out" <<'FAIL2BAN'
# ============================================================
#  Fail2ban
# ============================================================
step "Installing Fail2ban..."
pkg_install fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
INSTALLED+=("Fail2ban")
ok "Fail2ban installed"

FAIL2BAN
    fi

    # ================================================================
    #  Clone git repositories from projects.txt
    # ================================================================
    cat >> "$out" <<'CLONE_HEADER'
# ============================================================
#  Clone Git Repositories
# ============================================================
step "Cloning git repositories..."
CLONE_HEADER

    if [ -f "$SNAP_DIR/projects.txt" ]; then
        local current_path=""
        while IFS= read -r line; do
            # Parse "  Path:   /some/path"
            if [[ "$line" =~ ^[[:space:]]*Path:[[:space:]]*(.+)$ ]]; then
                current_path="${BASH_REMATCH[1]}"
            fi
            # Parse "  Remote: git@... or https://..."
            if [[ "$line" =~ ^[[:space:]]*Remote:[[:space:]]*(.+)$ ]]; then
                local remote="${BASH_REMATCH[1]}"
                if [[ "$remote" != "no remote" && -n "$remote" && -n "$current_path" ]]; then
                    local parent_dir
                    parent_dir=$(dirname "$current_path")
                    cat >> "$out" <<REPO
mkdir -p "$parent_dir"
git clone "$remote" "$current_path" 2>/dev/null && ok "Cloned $remote" || warn "Skipped $current_path (already exists or failed)"
REPO
                fi
                current_path=""
            fi
        done < "$SNAP_DIR/projects.txt"
    fi

    echo "" >> "$out"

    # ================================================================
    #  Install global npm packages from global-packages.txt
    # ================================================================
    cat >> "$out" <<'NPM_HEADER'
# ============================================================
#  Restore Global npm Packages
# ============================================================
step "Installing global npm packages..."
NPM_HEADER

    if [ -f "$SNAP_DIR/global-packages.txt" ]; then
        # Parse npm list output: lines like "+-- package@version" or "├── package@version"
        local npm_pkgs=()
        while IFS= read -r line; do
            # Match lines with package@version (skip npm itself and empty lines)
            local pkg
            pkg=$(echo "$line" | grep -oP '[\w@/.-]+@[\d.]+' 2>/dev/null | head -1) || true
            if [ -n "$pkg" ]; then
                local pkg_name="${pkg%@*}"
                # Skip npm itself and corepack (they come with node)
                if [[ "$pkg_name" != "npm" && "$pkg_name" != "corepack" ]]; then
                    npm_pkgs+=("$pkg_name")
                fi
            fi
        done < <(sed -n '/## npm global packages/,/^##/p' "$SNAP_DIR/global-packages.txt" 2>/dev/null)

        if [ ${#npm_pkgs[@]} -gt 0 ]; then
            echo "if command -v npm &>/dev/null; then" >> "$out"
            for p in "${npm_pkgs[@]}"; do
                echo "    sudo npm install -g \"$p\" 2>/dev/null || warn \"Failed to install npm package: $p\"" >> "$out"
            done
            echo "    ok \"Global npm packages installed\"" >> "$out"
            echo "fi" >> "$out"
        else
            echo "info \"No global npm packages to restore\"" >> "$out"
        fi
    else
        echo "info \"No global-packages.txt found — skipping npm globals\"" >> "$out"
    fi

    echo "" >> "$out"

    # ================================================================
    #  Install global pip packages from global-packages.txt
    # ================================================================
    cat >> "$out" <<'PIP_HEADER'
# ============================================================
#  Restore Global pip Packages
# ============================================================
step "Installing global pip packages..."
PIP_HEADER

    if [ -f "$SNAP_DIR/global-packages.txt" ]; then
        local pip_pkgs=()
        local in_pip_section=false
        local header_skipped=false
        while IFS= read -r line; do
            if [[ "$line" == *"## pip3 packages"* ]]; then
                in_pip_section=true
                header_skipped=false
                continue
            fi
            if [[ "$line" == "##"* ]] && [ "$in_pip_section" = true ]; then
                break
            fi
            if [ "$in_pip_section" = true ]; then
                # Skip the "---" separator and the header row (Package / Version)
                [[ "$line" == "---" ]] && continue
                [[ "$line" =~ ^Package ]] && { header_skipped=true; continue; }
                [[ "$line" =~ ^-+[[:space:]]+-+ ]] && continue
                [[ -z "$line" ]] && continue
                # Extract package name (first column)
                local pip_pkg
                pip_pkg=$(echo "$line" | awk '{print $1}')
                if [ -n "$pip_pkg" ]; then
                    # Skip pip, setuptools, wheel (they come with python)
                    if [[ "$pip_pkg" != "pip" && "$pip_pkg" != "setuptools" && "$pip_pkg" != "wheel" ]]; then
                        pip_pkgs+=("$pip_pkg")
                    fi
                fi
            fi
        done < "$SNAP_DIR/global-packages.txt"

        if [ ${#pip_pkgs[@]} -gt 0 ]; then
            echo "if command -v pip3 &>/dev/null; then" >> "$out"
            for p in "${pip_pkgs[@]}"; do
                echo "    pip3 install \"$p\" 2>/dev/null || warn \"Failed to install pip package: $p\"" >> "$out"
            done
            echo "    ok \"Global pip packages installed\"" >> "$out"
            echo "fi" >> "$out"
        else
            echo "info \"No global pip packages to restore\"" >> "$out"
        fi
    else
        echo "info \"No global-packages.txt found — skipping pip globals\"" >> "$out"
    fi

    echo "" >> "$out"

    # ================================================================
    #  Restore firewall rules from firewall.txt
    # ================================================================
    cat >> "$out" <<'FW_HEADER'
# ============================================================
#  Restore Firewall Rules (UFW)
# ============================================================
step "Restoring firewall rules..."
FW_HEADER

    if [ -f "$SNAP_DIR/firewall.txt" ]; then
        local ufw_rules=()
        while IFS= read -r line; do
            # Match UFW rule lines, e.g.:
            #   22/tcp                     ALLOW IN    Anywhere
            #   80,443/tcp                 ALLOW IN    Anywhere
            #   Nginx Full                 ALLOW IN    Anywhere
            if [[ "$line" =~ ^[[:space:]]*([0-9A-Za-z,/[:space:]]+)[[:space:]]+ALLOW ]]; then
                local rule
                rule=$(echo "$line" | awk '{print $1}')
                # Skip "Status:" or header lines
                if [[ -n "$rule" && "$rule" != "To" && "$rule" != "Status:" && "$rule" != "--" ]]; then
                    ufw_rules+=("$rule")
                fi
            fi
        done < "$SNAP_DIR/firewall.txt"

        if [ ${#ufw_rules[@]} -gt 0 ]; then
            echo "if command -v ufw &>/dev/null; then" >> "$out"
            echo "    pkg_install ufw" >> "$out"
            # Deduplicate (IPv4/IPv6 produce duplicate rule names)
            local seen_rules=()
            for r in "${ufw_rules[@]}"; do
                local already_seen=false
                for s in "${seen_rules[@]}"; do
                    if [[ "$s" == "$r" ]]; then
                        already_seen=true
                        break
                    fi
                done
                if [ "$already_seen" = false ]; then
                    seen_rules+=("$r")
                    echo "    sudo ufw allow $r || true" >> "$out"
                fi
            done
            echo "    sudo ufw --force enable" >> "$out"
            echo "    ok \"UFW rules restored\"" >> "$out"
            echo "else" >> "$out"
            echo "    warn \"ufw not available — install it and re-run this section\"" >> "$out"
            echo "fi" >> "$out"
        else
            echo "info \"No UFW rules found in firewall.txt\"" >> "$out"
        fi
    else
        echo "info \"No firewall.txt found — skipping firewall setup\"" >> "$out"
    fi

    echo "" >> "$out"

    # ================================================================
    #  Set timezone
    # ================================================================
    local tz=""
    if [ -f "$SNAP_DIR/system-info.txt" ]; then
        tz=$(grep "^Timezone:" "$SNAP_DIR/system-info.txt" 2>/dev/null | awk '{print $2}')
    fi

    if [ -n "$tz" ] && [ "$tz" != "N/A" ]; then
        cat >> "$out" <<TZ
# ============================================================
#  Set Timezone
# ============================================================
step "Setting timezone to ${tz}..."
sudo timedatectl set-timezone "${tz}" 2>/dev/null || warn "Could not set timezone"
ok "Timezone set to ${tz}"

TZ
    fi

    # ================================================================
    #  Set hostname
    # ================================================================
    local snap_hostname=""
    if [ -f "$SNAP_DIR/system-info.txt" ]; then
        snap_hostname=$(grep "^Hostname:" "$SNAP_DIR/system-info.txt" 2>/dev/null | awk '{print $2}')
    fi

    if [ -n "$snap_hostname" ] && [ "$snap_hostname" != "N/A" ]; then
        cat >> "$out" <<HN
# ============================================================
#  Set Hostname
# ============================================================
step "Setting hostname to ${snap_hostname}..."
sudo hostnamectl set-hostname "${snap_hostname}" 2>/dev/null || warn "Could not set hostname"
ok "Hostname set to ${snap_hostname}"

HN
    fi

    # ================================================================
    #  Summary footer
    # ================================================================
    cat >> "$out" <<'FOOTER'
# ============================================================
#  Summary
# ============================================================
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║         Reinstall Complete!                      ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}Installed:${NC}"
for item in "${INSTALLED[@]}"; do
    echo -e "    ${GREEN}*${NC} $item"
done
echo ""
echo -e "  ${BOLD}Manual steps remaining:${NC}"
echo -e "    ${YELLOW}1.${NC} Restore Nginx/Apache configs from the snapshot nginx/ directory"
echo -e "    ${YELLOW}2.${NC} Recreate .env files (see env-files.txt for key names)"
echo -e "    ${YELLOW}3.${NC} Restore cron jobs from cron.txt"
echo -e "    ${YELLOW}4.${NC} Restore SSL certificates (run certbot for each domain)"
echo -e "    ${YELLOW}5.${NC} Restore databases from backups"
echo -e "    ${YELLOW}6.${NC} Restore custom systemd services from systemd/"
echo -e "    ${YELLOW}7.${NC} Restore PM2 processes (pm2 start ecosystem.config.js)"
echo ""
echo -e "${GREEN}${BOLD}Done!${NC} Review the snapshot directory for configs that need manual restoration."
FOOTER

    chmod +x "$out"

    info "Reinstall script written to reinstall.sh"
    ok "Reinstall script generated ($(wc -l < "$out") lines)"
}
