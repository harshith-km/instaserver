import { useState, useMemo } from 'react'
import { Camera, Download, Terminal, Info } from 'lucide-react'
import { theme } from '../theme'
import CopyButton from './CopyButton'
import InfoModal from './InfoModal'

const SNAP_CMD = `bash <(curl -fsSL https://raw.githubusercontent.com/harshith-km/instaserver/main/snapshot.sh)`

const DEFAULT_SNAP_CONFIG = {
  systemInfo: true,
  packages: true,
  services: true,
  projects: true,
  directoryTree: true,
  nginx: true,
  apache: false,
  ssl: true,
  databases: true,
  docker: true,
  pm2: true,
  ssh: true,
  firewall: true,
  users: true,
  envFiles: true,
  shellConfig: true,
  cron: true,
  systemdTimers: true,
  logrotate: true,
  globalPackages: true,
  sysctl: true,
  network: true,
  diskMounts: true,
  awsInfo: true,
  systemdServices: true,
  generateReinstall: true,
  scanDirs: '$HOME /var/www /opt /srv',
  maxDepth: '4',
}

const SNAP_INFO = {
  systemInfo: {
    title: 'System Information',
    description: 'Captures your server\'s identity — hostname, OS, kernel, CPU, RAM, disk, IPs, timezone.',
    details: ['Hostname, OS name & version', 'CPU cores & model, RAM & swap', 'Public & private IP addresses', 'Disk usage, timezone, default shell'],
  },
  packages: {
    title: 'Installed Packages & Versions',
    description: 'Full list of every installed package plus key software versions (Node, Python, Docker, Nginx, etc.).',
    details: ['Complete dpkg/rpm package list', 'Key tool versions: node, python, docker, nginx, git, pm2, aws, databases, etc.'],
  },
  projects: {
    title: 'Git Projects & Frameworks',
    description: 'Finds all git repos, captures remote URLs, branches, and auto-detects project type and framework.',
    details: ['Git remote URL, current branch, last commit', 'Detects: Node, Python, Docker, Go, Rust, Ruby, Java', 'Frameworks: Next.js, React, Vue, Express, NestJS, Django, FastAPI, Flask'],
  },
  nginx: {
    title: 'Nginx Configuration',
    description: 'Full copy of your Nginx setup — main config, all sites, and a complete config dump.',
    details: ['nginx.conf, sites-available/, conf.d/', 'sites-enabled symlink list', 'Full config dump via nginx -T'],
  },
  databases: {
    title: 'Database Information',
    description: 'Detects running databases and lists their database names.',
    details: ['PostgreSQL: version, status, database list', 'MySQL/MariaDB: version, status, database list', 'MongoDB: version, status, database list', 'Redis: version, status, DB size'],
  },
  docker: {
    title: 'Docker State',
    description: 'Complete snapshot of containers, images, volumes, networks, and compose files.',
    details: ['Running & stopped containers with ports', 'Images with sizes', 'Volumes & networks', 'Copies all docker-compose.yml files found'],
  },
  users: {
    title: 'User Accounts & Sudo',
    description: 'Lists non-system users (UID >= 1000), their groups, home directories, and sudo access.',
    details: ['Username, UID, groups, home dir, shell', 'Sudo/wheel group membership', 'Sudoers file entries'],
  },
  envFiles: {
    title: 'Environment Files',
    description: 'Finds .env files and records their KEY NAMES only — never captures secret values.',
    details: ['File path, size, variable count', 'Key names only (PORT, DB_HOST, etc.)', 'Also finds systemd EnvironmentFile references'],
  },
  shellConfig: {
    title: 'Shell Configuration',
    description: 'Copies your .bashrc, .profile, .zshrc so custom aliases, PATH, and env vars aren\'t lost.',
    details: ['Copies ~/.bashrc, ~/.bash_profile, ~/.profile, ~/.zshrc', 'Extracts custom additions vs default system config'],
  },
  globalPackages: {
    title: 'Global npm & pip Packages',
    description: 'Captures globally installed packages that aren\'t in any project\'s package.json.',
    details: ['npm list -g (pm2, nodemon, etc.)', 'pip3 list (awscli, gunicorn, etc.)'],
  },
  awsInfo: {
    title: 'AWS EC2 Metadata',
    description: 'If running on EC2, captures instance ID, type, region, and IAM role via instance metadata.',
    details: ['Instance ID, type, AMI ID', 'Region & availability zone', 'IAM role attached', 'AWS CLI configuration status'],
  },
  generateReinstall: {
    title: 'Generate Reinstall Script',
    description: 'Auto-generates a reinstall.sh that can recreate this server — installs all detected software, clones repos, restores global packages.',
    details: ['Install commands for all detected tools', 'git clone for every repo found', 'npm install -g / pip3 install for globals', 'Firewall rules, timezone, hostname'],
  },
}

function generateSnapshotScript(c) {
  let s = `#!/bin/bash
set -e

# ============================================================
#  instaserver - Custom Snapshot Script
#  Generated at https://harshith-km.github.io/instaserver
# ============================================================

RED='\\033[0;31m'
GREEN='\\033[0;32m'
BLUE='\\033[0;34m'
CYAN='\\033[0;36m'
YELLOW='\\033[1;33m'
BOLD='\\033[1m'
NC='\\033[0m'

step() { echo -e "\\n\${BLUE}[SCAN]\${NC} \${BOLD}\$1\${NC}"; }
ok() { echo -e "\${GREEN}  [OK]\${NC} \$1"; }
warn() { echo -e "\${YELLOW}  [SKIP]\${NC} \$1"; }

TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
SNAP_DIR="$HOME/server-snapshot-$TIMESTAMP"
mkdir -p "$SNAP_DIR"

SCAN_DIRS=(${c.scanDirs})
MAX_DEPTH=${c.maxDepth}

echo -e "\${CYAN}"
echo "╔══════════════════════════════════════════════════╗"
echo "║        instaserver - Server Snapshot             ║"
echo "╚══════════════════════════════════════════════════╝"
echo -e "\${NC}"
echo -e "Output: \${BOLD}$SNAP_DIR/\${NC}"
echo ""
`

  if (c.systemInfo) {
    s += `
# ============================================================
#  System Information
# ============================================================
step "System information..."
cat > "$SNAP_DIR/system-info.txt" <<SYSEOF
Hostname:       $(hostname)
OS:             $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2)
Kernel:         $(uname -r)
Architecture:   $(uname -m)
Uptime:         $(uptime -p 2>/dev/null || uptime)
Public IP:      $(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "N/A")
Private IP:     $(hostname -I 2>/dev/null | awk '{print $1}')
CPU:            $(grep -c ^processor /proc/cpuinfo 2>/dev/null || echo "N/A") cores
Total RAM:      $(free -h 2>/dev/null | awk '/Mem:/ {print $2}')
Total Disk:     $(df -h / 2>/dev/null | awk 'NR==2 {print $2}')
Used Disk:      $(df -h / 2>/dev/null | awk 'NR==2 {print $3 " (" $5 ")"}')
Swap:           $(free -h 2>/dev/null | awk '/Swap:/ {print $2}')
Timezone:       $(timedatectl show --property=Timezone --value 2>/dev/null || cat /etc/timezone 2>/dev/null || echo "N/A")
SYSEOF
ok "System info saved"
`
  }

  if (c.packages) {
    s += `
# ============================================================
#  Installed Packages
# ============================================================
step "Installed packages..."
{
    if command -v dpkg &>/dev/null; then
        dpkg -l 2>/dev/null | grep ^ii | awk '{print $2 "\\t" $3}'
    elif command -v rpm &>/dev/null; then
        rpm -qa --qf '%{NAME}\\t%{VERSION}-%{RELEASE}\\n' 2>/dev/null | sort
    fi
} > "$SNAP_DIR/packages-all.txt"

{
    for cmd_check in \\
        "node:node -v" "npm:npm -v" "python3:python3 --version" \\
        "docker:docker --version" "nginx:nginx -v 2>&1" \\
        "git:git --version" "pm2:pm2 -v" "aws:aws --version" \\
        "certbot:certbot --version 2>&1" "psql:psql --version" \\
        "mysql:mysql --version" "redis-server:redis-server --version" \\
    ; do
        name="\${cmd_check%%:*}"
        cmd="\${cmd_check#*:}"
        if command -v "$name" &>/dev/null; then
            echo "$name: $(eval "$cmd" 2>/dev/null)"
        fi
    done
} > "$SNAP_DIR/versions.txt"
ok "Package lists saved"
`
  }

  if (c.services) {
    s += `
# ============================================================
#  Running Services & Ports
# ============================================================
step "Running services..."
systemctl list-units --type=service --state=running --no-pager > "$SNAP_DIR/services.txt" 2>/dev/null
ss -tlnp > "$SNAP_DIR/ports.txt" 2>/dev/null || netstat -tlnp > "$SNAP_DIR/ports.txt" 2>/dev/null
ok "Services and ports saved"
`
  }

  if (c.projects) {
    s += `
# ============================================================
#  Git Projects
# ============================================================
step "Scanning projects..."
{
    for scan_dir in "\${SCAN_DIRS[@]}"; do
        [ ! -d "$scan_dir" ] && continue
        echo "## $scan_dir"
        while IFS= read -r git_dir; do
            repo_dir=$(dirname "$git_dir")
            echo ""
            echo "### \${repo_dir#$scan_dir/}"
            echo "  Path:   $repo_dir"
            echo "  Remote: $(git -C "$repo_dir" remote get-url origin 2>/dev/null || echo 'no remote')"
            echo "  Branch: $(git -C "$repo_dir" branch --show-current 2>/dev/null || echo 'unknown')"
            echo "  Last:   $(git -C "$repo_dir" log -1 --format='%h %s (%cr)' 2>/dev/null || echo 'unknown')"
            [ -f "$repo_dir/package.json" ] && echo "  Type:   Node.js"
            [ -f "$repo_dir/requirements.txt" ] && echo "  Type:   Python"
            [ -f "$repo_dir/Dockerfile" ] && echo "  Type:   Docker"
            [ -f "$repo_dir/go.mod" ] && echo "  Type:   Go"
        done < <(find "$scan_dir" -maxdepth $MAX_DEPTH -name ".git" -type d 2>/dev/null)
    done
} > "$SNAP_DIR/projects.txt"
ok "Projects saved"
`
  }

  if (c.directoryTree) {
    s += `
# ============================================================
#  Directory Trees
# ============================================================
step "Directory structure..."
{
    for dir in "\${SCAN_DIRS[@]}"; do
        [ -d "$dir" ] || continue
        echo "## $dir"
        if command -v tree &>/dev/null; then
            tree -L 2 -d --noreport "$dir" 2>/dev/null
        else
            find "$dir" -maxdepth 2 -type d 2>/dev/null | head -50
        fi
        echo ""
    done
} > "$SNAP_DIR/directory-tree.txt"
ok "Directory trees saved"
`
  }

  if (c.nginx) {
    s += `
# ============================================================
#  Nginx Configuration
# ============================================================
step "Nginx configuration..."
if command -v nginx &>/dev/null; then
    mkdir -p "$SNAP_DIR/nginx"
    cp /etc/nginx/nginx.conf "$SNAP_DIR/nginx/" 2>/dev/null || true
    [ -d "/etc/nginx/sites-available" ] && cp -r /etc/nginx/sites-available "$SNAP_DIR/nginx/" 2>/dev/null
    [ -d "/etc/nginx/conf.d" ] && cp -r /etc/nginx/conf.d "$SNAP_DIR/nginx/" 2>/dev/null
    ls -la /etc/nginx/sites-enabled/ > "$SNAP_DIR/nginx/sites-enabled-list.txt" 2>/dev/null || true
    nginx -T > "$SNAP_DIR/nginx/full-config-dump.txt" 2>/dev/null || true
    ok "Nginx configs saved"
else
    warn "Nginx not found"
fi
`
  }

  if (c.apache) {
    s += `
# ============================================================
#  Apache Configuration
# ============================================================
step "Apache configuration..."
if command -v apache2 &>/dev/null || command -v httpd &>/dev/null; then
    mkdir -p "$SNAP_DIR/apache"
    cp -r /etc/apache2/sites-available "$SNAP_DIR/apache/" 2>/dev/null || true
    cp -r /etc/httpd/conf.d "$SNAP_DIR/apache/" 2>/dev/null || true
    ok "Apache configs saved"
else
    warn "Apache not found"
fi
`
  }

  if (c.ssl) {
    s += `
# ============================================================
#  SSL Certificates
# ============================================================
step "SSL certificates..."
{
    if [ -d "/etc/letsencrypt/live" ]; then
        for cert_dir in /etc/letsencrypt/live/*/; do
            domain=$(basename "$cert_dir")
            [ "$domain" == "README" ] && continue
            expiry=$(openssl x509 -enddate -noout -in "$cert_dir/fullchain.pem" 2>/dev/null | cut -d= -f2)
            echo "$domain (expires: $expiry)"
        done
    else
        echo "No Let's Encrypt certificates found"
    fi
} > "$SNAP_DIR/ssl.txt"
ok "SSL info saved"
`
  }

  if (c.databases) {
    s += `
# ============================================================
#  Databases
# ============================================================
step "Database information..."
{
    command -v psql &>/dev/null && echo "## PostgreSQL" && echo "  Version: $(psql --version 2>/dev/null)" && echo "  Status: $(systemctl is-active postgresql 2>/dev/null)" && echo "  Databases:" && sudo -u postgres psql -l --no-align 2>/dev/null | grep '|' | cut -d'|' -f1 | while read db; do echo "    - $db"; done && echo ""
    command -v mysql &>/dev/null && echo "## MySQL" && echo "  Version: $(mysql --version 2>/dev/null)" && echo "  Databases:" && mysql -e "SHOW DATABASES;" 2>/dev/null | tail -n +2 | while read db; do echo "    - $db"; done && echo ""
    command -v redis-cli &>/dev/null && echo "## Redis" && echo "  Version: $(redis-server --version 2>/dev/null)" && echo "  Status: $(systemctl is-active redis 2>/dev/null || systemctl is-active redis-server 2>/dev/null)" && echo ""
} > "$SNAP_DIR/databases.txt"
ok "Database info saved"
`
  }

  if (c.docker) {
    s += `
# ============================================================
#  Docker
# ============================================================
step "Docker state..."
if command -v docker &>/dev/null; then
    {
        echo "## Running Containers"
        docker ps --format "table {{.Names}}\\t{{.Image}}\\t{{.Status}}\\t{{.Ports}}" 2>/dev/null
        echo ""
        echo "## Images"
        docker images --format "table {{.Repository}}\\t{{.Tag}}\\t{{.Size}}" 2>/dev/null
        echo ""
        echo "## Volumes"
        docker volume ls 2>/dev/null
    } > "$SNAP_DIR/docker.txt"
    mkdir -p "$SNAP_DIR/docker-compose"
    find "\${SCAN_DIRS[@]}" -maxdepth $MAX_DEPTH \\( -name "docker-compose.yml" -o -name "compose.yml" \\) 2>/dev/null | while read f; do
        cp "$f" "$SNAP_DIR/docker-compose/$(echo "$f" | sed 's|/|__|g')" 2>/dev/null || true
    done
    ok "Docker state saved"
else
    warn "Docker not found"
fi
`
  }

  if (c.pm2) {
    s += `
# ============================================================
#  PM2
# ============================================================
step "PM2 processes..."
if command -v pm2 &>/dev/null; then
    { pm2 list 2>/dev/null; echo ""; pm2 jlist 2>/dev/null; } > "$SNAP_DIR/pm2.txt"
    pm2 save 2>/dev/null || true
    [ -f "$HOME/.pm2/dump.pm2" ] && cp "$HOME/.pm2/dump.pm2" "$SNAP_DIR/pm2-dump.json" 2>/dev/null
    ok "PM2 saved"
else
    warn "PM2 not found"
fi
`
  }

  if (c.ssh) {
    s += `
# ============================================================
#  SSH Configuration
# ============================================================
step "SSH configuration..."
{
    echo "## sshd_config"
    for s in Port PermitRootLogin PasswordAuthentication PubkeyAuthentication ClientAliveInterval MaxAuthTries; do
        grep -i "^$s" /etc/ssh/sshd_config 2>/dev/null || echo "$s: (default)"
    done
    echo ""
    echo "## Authorized Keys"
    [ -f "$HOME/.ssh/authorized_keys" ] && echo "  $(wc -l < "$HOME/.ssh/authorized_keys") key(s)" || echo "  (none)"
    echo ""
    echo "## SSH Keys"
    ls -la "$HOME/.ssh/" 2>/dev/null | grep -v authorized_keys | grep -v known_hosts
} > "$SNAP_DIR/ssh.txt"
ok "SSH config saved"
`
  }

  if (c.firewall) {
    s += `
# ============================================================
#  Firewall
# ============================================================
step "Firewall rules..."
{
    command -v ufw &>/dev/null && echo "## UFW" && sudo ufw status verbose 2>/dev/null
    command -v firewall-cmd &>/dev/null && echo "## firewalld" && sudo firewall-cmd --list-all 2>/dev/null
    echo ""
    echo "## iptables"
    sudo iptables -L -n --line-numbers 2>/dev/null | head -50
} > "$SNAP_DIR/firewall.txt"
ok "Firewall rules saved"
`
  }

  if (c.users) {
    s += `
# ============================================================
#  User Accounts
# ============================================================
step "User accounts..."
{
    echo "## Non-system users (UID >= 1000)"
    awk -F: '$3 >= 1000 && $1 != "nobody" {printf "  %-15s UID=%-6s Home=%-20s Shell=%s\\n", $1, $3, $6, $7}' /etc/passwd
    echo ""
    echo "## Sudo access"
    grep -v '^#' /etc/sudoers 2>/dev/null | grep -v '^$' | head -20
    getent group sudo 2>/dev/null || getent group wheel 2>/dev/null
} > "$SNAP_DIR/users.txt"
ok "User accounts saved"
`
  }

  if (c.envFiles) {
    s += `
# ============================================================
#  Environment Files (keys only)
# ============================================================
step "Environment files..."
{
    echo "## .env files (keys only, no secrets)"
    find "\${SCAN_DIRS[@]}" -maxdepth $MAX_DEPTH \\( -name ".env" -o -name ".env.*" \\) 2>/dev/null | while read f; do
        vars=$(grep -c "=" "$f" 2>/dev/null || echo "?")
        echo "  $f ($vars variables)"
        echo "    Keys: $(grep -oP '^[A-Za-z_][A-Za-z0-9_]*(?==)' "$f" 2>/dev/null | tr '\\n' ', ')"
    done
} > "$SNAP_DIR/env-files.txt"
ok "Environment file locations saved"
`
  }

  if (c.shellConfig) {
    s += `
# ============================================================
#  Shell Configuration
# ============================================================
step "Shell config..."
mkdir -p "$SNAP_DIR/shell-config"
for rc in .bashrc .bash_profile .profile .zshrc; do
    [ -f "$HOME/$rc" ] && cp "$HOME/$rc" "$SNAP_DIR/shell-config/" 2>/dev/null
done
ok "Shell config saved"
`
  }

  if (c.cron) {
    s += `
# ============================================================
#  Cron Jobs
# ============================================================
step "Cron jobs..."
{
    echo "## User crontab ($USER)"
    crontab -l 2>/dev/null || echo "  (none)"
    echo ""
    echo "## Root crontab"
    sudo crontab -l 2>/dev/null || echo "  (none or no sudo)"
    echo ""
    echo "## /etc/cron.d/"
    ls -la /etc/cron.d/ 2>/dev/null
} > "$SNAP_DIR/cron.txt"
ok "Cron jobs saved"
`
  }

  if (c.systemdTimers) {
    s += `
# ============================================================
#  Systemd Timers
# ============================================================
step "Systemd timers..."
systemctl list-timers --all --no-pager > "$SNAP_DIR/timers.txt" 2>/dev/null
ok "Timers saved"
`
  }

  if (c.logrotate) {
    s += `
# ============================================================
#  Logrotate
# ============================================================
step "Logrotate configs..."
mkdir -p "$SNAP_DIR/logrotate"
cp /etc/logrotate.d/* "$SNAP_DIR/logrotate/" 2>/dev/null || true
ok "Logrotate saved"
`
  }

  if (c.globalPackages) {
    s += `
# ============================================================
#  Global Packages
# ============================================================
step "Global packages..."
{
    command -v npm &>/dev/null && echo "## npm global" && npm list -g --depth=0 2>/dev/null
    echo ""
    command -v pip3 &>/dev/null && echo "## pip3" && pip3 list --format=columns 2>/dev/null
} > "$SNAP_DIR/global-packages.txt"
ok "Global packages saved"
`
  }

  if (c.sysctl) {
    s += `
# ============================================================
#  Sysctl
# ============================================================
step "Sysctl config..."
mkdir -p "$SNAP_DIR/sysctl"
cp /etc/sysctl.conf "$SNAP_DIR/sysctl/" 2>/dev/null || true
cp /etc/sysctl.d/*.conf "$SNAP_DIR/sysctl/" 2>/dev/null || true
ok "Sysctl saved"
`
  }

  if (c.network) {
    s += `
# ============================================================
#  Network Configuration
# ============================================================
step "Network config..."
{
    echo "## Hostname: $(hostname)"
    echo ""
    echo "## /etc/hosts"
    cat /etc/hosts 2>/dev/null
    echo ""
    echo "## /etc/resolv.conf"
    cat /etc/resolv.conf 2>/dev/null
    echo ""
    echo "## IP Addresses"
    ip addr 2>/dev/null || ifconfig 2>/dev/null
} > "$SNAP_DIR/network.txt"
ok "Network config saved"
`
  }

  if (c.diskMounts) {
    s += `
# ============================================================
#  Disk Mounts
# ============================================================
step "Disk mounts..."
{
    echo "## /etc/fstab"
    cat /etc/fstab 2>/dev/null
    echo ""
    echo "## lsblk"
    lsblk 2>/dev/null
    echo ""
    echo "## df -h"
    df -h 2>/dev/null
} > "$SNAP_DIR/disk.txt"
ok "Disk info saved"
`
  }

  if (c.awsInfo) {
    s += `
# ============================================================
#  AWS EC2 Metadata
# ============================================================
step "AWS instance info..."
{
    TOKEN=$(curl -s --max-time 2 -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" 2>/dev/null)
    if [ -n "$TOKEN" ]; then
        HEADER="X-aws-ec2-metadata-token: $TOKEN"
        echo "Instance ID:   $(curl -s -H "$HEADER" http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null)"
        echo "Instance Type: $(curl -s -H "$HEADER" http://169.254.169.254/latest/meta-data/instance-type 2>/dev/null)"
        echo "Region:        $(curl -s -H "$HEADER" http://169.254.169.254/latest/meta-data/placement/region 2>/dev/null)"
        echo "IAM Role:      $(curl -s -H "$HEADER" http://169.254.169.254/latest/meta-data/iam/security-credentials/ 2>/dev/null)"
    else
        echo "Not running on EC2 (or IMDS unavailable)"
    fi
    echo ""
    command -v aws &>/dev/null && echo "## AWS CLI Config" && aws configure list 2>/dev/null
} > "$SNAP_DIR/aws-instance.txt"
ok "AWS info saved"
`
  }

  if (c.systemdServices) {
    s += `
# ============================================================
#  Custom Systemd Services
# ============================================================
step "Custom systemd services..."
mkdir -p "$SNAP_DIR/systemd"
find /etc/systemd/system -maxdepth 1 -name "*.service" -type f 2>/dev/null | while read f; do
    cp "$f" "$SNAP_DIR/systemd/" 2>/dev/null || true
done
ok "Systemd services saved"
`
  }

  if (c.generateReinstall) {
    s += `
# ============================================================
#  Generate Reinstall Script
# ============================================================
step "Generating reinstall script..."
{
    echo '#!/bin/bash'
    echo 'set -e'
    echo 'echo "Reinstall script - review before running!"'
    echo '# Auto-generated from snapshot'
    echo ''
    echo '# Detect OS'
    echo 'if [ -f /etc/os-release ]; then'
    echo '    . /etc/os-release'
    echo '    [[ "$ID" == "ubuntu" || "$ID" == "debian" ]] && PKG="apt" || PKG="yum"'
    echo 'fi'
    echo ''
    echo '# Update system'
    echo 'if [[ "$PKG" == "apt" ]]; then sudo apt-get update -y && sudo apt-get upgrade -y; else sudo yum update -y; fi'

    # Detect and add install commands for found tools
    command -v node &>/dev/null && echo "# Node.js $(node -v)" && echo 'curl -fsSL "https://deb.nodesource.com/setup_'$(node -v | grep -oP '\\d+' | head -1)'.x" | sudo -E bash - && sudo apt-get install -y nodejs 2>/dev/null || { curl -fsSL "https://rpm.nodesource.com/setup_'$(node -v | grep -oP '\\d+' | head -1)'.x" | sudo bash - && sudo yum install -y nodejs; }'
    command -v pm2 &>/dev/null && echo 'sudo npm install -g pm2'
    command -v nginx &>/dev/null && echo 'sudo apt-get install -y nginx 2>/dev/null || sudo yum install -y nginx'
    command -v docker &>/dev/null && echo 'curl -fsSL https://get.docker.com | sudo sh && sudo usermod -aG docker "$USER"'

    # Clone repos
    grep "Remote:" "$SNAP_DIR/projects.txt" 2>/dev/null | while read line; do
        remote=$(echo "$line" | sed 's/.*Remote: *//')
        [[ "$remote" != "no remote" && -n "$remote" ]] && echo "git clone \\"$remote\\" 2>/dev/null || true"
    done

    echo ''
    echo 'echo "Reinstall complete! Review nginx/, cron.txt, env-files.txt for manual restore."'
} > "$SNAP_DIR/reinstall.sh"
chmod +x "$SNAP_DIR/reinstall.sh"
ok "Reinstall script generated"
`
  }

  s += `
# ============================================================
#  Summary
# ============================================================
echo ""
echo -e "\${CYAN}╔══════════════════════════════════════════════════╗\${NC}"
echo -e "\${CYAN}║        Snapshot Complete!                        ║\${NC}"
echo -e "\${CYAN}╚══════════════════════════════════════════════════╝\${NC}"
echo ""
echo -e "  \${BOLD}Location:\${NC}  $SNAP_DIR/"
total_size=$(du -sh "$SNAP_DIR" 2>/dev/null | cut -f1)
echo -e "  \${BOLD}Total:\${NC}     $total_size"
echo ""
`

  return s
}

function Toggle({ label, checked, onChange, infoKey, onInfo }) {
  return (
    <div className="flex items-center gap-3 py-2 text-sm">
      <label className="flex items-center gap-3 cursor-pointer select-none flex-1">
        <div
          onClick={(e) => { e.preventDefault(); onChange(!checked) }}
          className={`relative w-10 h-[22px] rounded-full shrink-0 cursor-pointer ${
            checked ? theme.toggleOn : theme.toggleOff
          }`}
        >
          <div className={`absolute top-[3px] left-[3px] w-4 h-4 ${theme.toggleKnob} rounded-full transition-transform ${
            checked ? 'translate-x-[18px]' : ''
          }`} />
        </div>
        <span className={theme.toggleLabel}>{label}</span>
      </label>
      {infoKey && SNAP_INFO[infoKey] && (
        <button
          onClick={(e) => { e.preventDefault(); onInfo(SNAP_INFO[infoKey]) }}
          className={`shrink-0 p-1 rounded-md ${theme.muted} hover:text-[#3b82f6] dark:hover:text-[#22d3ee] transition-colors cursor-pointer`}
        >
          <Info size={15} />
        </button>
      )}
    </div>
  )
}

function OptionGroup({ title, children }) {
  return (
    <div className={`${theme.optionGroup} rounded-xl p-5`}>
      <h3 className={`text-xs uppercase tracking-widest font-semibold mb-4 pb-2.5 ${theme.optionGroupTitle}`}>
        {title}
      </h3>
      <div className="space-y-0.5">{children}</div>
    </div>
  )
}

export default function Snapshot() {
  const [config, setConfig] = useState(DEFAULT_SNAP_CONFIG)
  const [activeInfo, setActiveInfo] = useState(null)
  const [showBuilder, setShowBuilder] = useState(false)

  const update = (key, value) => setConfig((prev) => ({ ...prev, [key]: value }))

  const script = useMemo(() => generateSnapshotScript(config), [config])

  const selectedCount = Object.entries(config).filter(([k, v]) => v === true).length

  const handleDownload = () => {
    const blob = new Blob([script], { type: 'text/x-shellscript' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = 'snapshot.sh'
    a.click()
    URL.revokeObjectURL(url)
  }

  return (
    <section className="px-4 sm:px-6 py-20 max-w-7xl mx-auto" id="snapshot">
      {/* Header */}
      <div className="text-center mb-12 animate-fade-in-up">
        <div className={`inline-flex items-center justify-center w-12 h-12 rounded-2xl mb-4 ${theme.accentBg}`}>
          <Camera size={24} className="text-white" />
        </div>
        <h2 className={`text-3xl sm:text-4xl font-bold mb-3 ${theme.heading}`}>Server Snapshot</h2>
        <p className={`${theme.muted} text-lg max-w-lg mx-auto mb-6`}>
          Capture your entire server state. Replicate it anywhere.
        </p>

        {/* Full snapshot command */}
        <div className={`${theme.commandBar} rounded-2xl p-5 mb-6 max-w-2xl mx-auto text-left`}>
          <div className="flex items-center gap-2 mb-3">
            <span className="w-2.5 h-2.5 rounded-full bg-red-400/70" />
            <span className="w-2.5 h-2.5 rounded-full bg-yellow-400/70" />
            <span className="w-2.5 h-2.5 rounded-full bg-green-400/70" />
            <span className={`ml-2 text-xs font-medium ${theme.muted}`}>Full snapshot (everything)</span>
          </div>
          <code className={`font-mono text-sm ${theme.commandText} break-all leading-relaxed block mb-4`}>
            <span className={theme.muted}>$ </span>{SNAP_CMD}
          </code>
          <CopyButton text={SNAP_CMD} />
        </div>

        {/* Toggle builder */}
        <button
          onClick={() => setShowBuilder(!showBuilder)}
          className={`inline-flex items-center gap-2 px-5 py-2.5 text-sm font-semibold rounded-xl ${showBuilder ? theme.btnPrimary : theme.btnSecondary}`}
        >
          <Terminal size={16} />
          {showBuilder ? 'Hide Custom Builder' : 'Build Custom Snapshot Script'}
        </button>
      </div>

      {/* Custom builder */}
      {showBuilder && (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 items-start animate-fade-in-up">
          {/* Options */}
          <div className="flex flex-col gap-4 animate-slide-left">
            <OptionGroup title="System">
              <Toggle label="System info (OS, CPU, RAM, IPs)" checked={config.systemInfo} onChange={(v) => update('systemInfo', v)} infoKey="systemInfo" onInfo={setActiveInfo} />
              <Toggle label="Installed packages & versions" checked={config.packages} onChange={(v) => update('packages', v)} infoKey="packages" onInfo={setActiveInfo} />
              <Toggle label="Running services & ports" checked={config.services} onChange={(v) => update('services', v)} />
            </OptionGroup>

            <OptionGroup title="Projects">
              <Toggle label="Git repos (remotes, branches, frameworks)" checked={config.projects} onChange={(v) => update('projects', v)} infoKey="projects" onInfo={setActiveInfo} />
              <Toggle label="Directory tree" checked={config.directoryTree} onChange={(v) => update('directoryTree', v)} />
              <div className="flex items-center gap-3 py-2 text-sm pl-8">
                <label className={`min-w-[100px] ${theme.inputLabel}`}>Scan dirs</label>
                <input type="text" value={config.scanDirs} onChange={(e) => update('scanDirs', e.target.value)}
                  className={`flex-1 px-3 py-2 rounded-lg text-sm ${theme.input}`} />
              </div>
              <div className="flex items-center gap-3 py-2 text-sm pl-8">
                <label className={`min-w-[100px] ${theme.inputLabel}`}>Max depth</label>
                <input type="text" value={config.maxDepth} onChange={(e) => update('maxDepth', e.target.value)}
                  className={`w-20 px-3 py-2 rounded-lg text-sm ${theme.input}`} />
              </div>
            </OptionGroup>

            <OptionGroup title="Web Server & SSL">
              <Toggle label="Nginx config" checked={config.nginx} onChange={(v) => update('nginx', v)} infoKey="nginx" onInfo={setActiveInfo} />
              <Toggle label="Apache config" checked={config.apache} onChange={(v) => update('apache', v)} />
              <Toggle label="SSL certificates" checked={config.ssl} onChange={(v) => update('ssl', v)} />
            </OptionGroup>

            <OptionGroup title="Databases & Containers">
              <Toggle label="Databases (PostgreSQL, MySQL, MongoDB, Redis)" checked={config.databases} onChange={(v) => update('databases', v)} infoKey="databases" onInfo={setActiveInfo} />
              <Toggle label="Docker (containers, images, compose)" checked={config.docker} onChange={(v) => update('docker', v)} infoKey="docker" onInfo={setActiveInfo} />
              <Toggle label="PM2 processes" checked={config.pm2} onChange={(v) => update('pm2', v)} />
            </OptionGroup>

            <OptionGroup title="Security & Users">
              <Toggle label="SSH configuration" checked={config.ssh} onChange={(v) => update('ssh', v)} />
              <Toggle label="Firewall rules" checked={config.firewall} onChange={(v) => update('firewall', v)} />
              <Toggle label="User accounts & sudo access" checked={config.users} onChange={(v) => update('users', v)} infoKey="users" onInfo={setActiveInfo} />
            </OptionGroup>

            <OptionGroup title="Environment & Shell">
              <Toggle label=".env file locations (keys only)" checked={config.envFiles} onChange={(v) => update('envFiles', v)} infoKey="envFiles" onInfo={setActiveInfo} />
              <Toggle label="Shell config (.bashrc, .zshrc)" checked={config.shellConfig} onChange={(v) => update('shellConfig', v)} infoKey="shellConfig" onInfo={setActiveInfo} />
              <Toggle label="Global npm & pip packages" checked={config.globalPackages} onChange={(v) => update('globalPackages', v)} infoKey="globalPackages" onInfo={setActiveInfo} />
            </OptionGroup>

            <OptionGroup title="System Config">
              <Toggle label="Cron jobs" checked={config.cron} onChange={(v) => update('cron', v)} />
              <Toggle label="Systemd timers" checked={config.systemdTimers} onChange={(v) => update('systemdTimers', v)} />
              <Toggle label="Logrotate configs" checked={config.logrotate} onChange={(v) => update('logrotate', v)} />
              <Toggle label="Sysctl kernel tuning" checked={config.sysctl} onChange={(v) => update('sysctl', v)} />
              <Toggle label="Network config" checked={config.network} onChange={(v) => update('network', v)} />
              <Toggle label="Disk mounts & fstab" checked={config.diskMounts} onChange={(v) => update('diskMounts', v)} />
              <Toggle label="AWS EC2 metadata & IAM role" checked={config.awsInfo} onChange={(v) => update('awsInfo', v)} infoKey="awsInfo" onInfo={setActiveInfo} />
              <Toggle label="Custom systemd services" checked={config.systemdServices} onChange={(v) => update('systemdServices', v)} />
            </OptionGroup>

            <OptionGroup title="Output">
              <Toggle label="Generate reinstall.sh" checked={config.generateReinstall} onChange={(v) => update('generateReinstall', v)} infoKey="generateReinstall" onInfo={setActiveInfo} />
            </OptionGroup>
          </div>

          {/* Preview */}
          <div className={`sticky top-4 ${theme.previewContainer} rounded-xl overflow-hidden animate-slide-right`}>
            <div className={`${theme.previewHeader} px-4 py-3`}>
              <div className="flex items-center justify-between flex-wrap gap-3">
                <div className={`flex items-center gap-2 ${theme.previewHeaderText} text-sm font-medium`}>
                  <div className="flex gap-1.5">
                    <span className="w-3 h-3 rounded-full bg-red-400/80" />
                    <span className="w-3 h-3 rounded-full bg-yellow-400/80" />
                    <span className="w-3 h-3 rounded-full bg-green-400/80" />
                  </div>
                  <span className="ml-2">snapshot.sh</span>
                  <span className={`${theme.optionCountBadge} px-2.5 py-0.5 rounded-full text-xs font-semibold`}>
                    {selectedCount} scans
                  </span>
                </div>
                <div className="flex gap-2">
                  <CopyButton text={script} label="Copy" />
                  <button onClick={handleDownload}
                    className={`inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium rounded-lg border ${theme.btnAction}`}>
                    <Download size={14} /> Download
                  </button>
                </div>
              </div>
            </div>
            <pre className={`p-4 overflow-auto max-h-[75vh] lg:max-h-[82vh] font-mono text-xs leading-relaxed ${theme.codeText} preview-scroll`}>
              <code>{script}</code>
            </pre>
          </div>
        </div>
      )}

      <InfoModal info={activeInfo} onClose={() => setActiveInfo(null)} />
    </section>
  )
}
