import { useState, useMemo } from 'react'
import { Download, Terminal } from 'lucide-react'
import { theme } from '../theme'
import CopyButton from './CopyButton'

const DEFAULT_CONFIG = {
  updateSystem: true,
  setupSwap: false,
  swapSize: '2G',
  timezone: '',
  backendRuntime: 'none',
  nodeVersion: '20',
  installPm2: false,
  installNginx: false,
  setupProxy: false,
  proxyPort: '3000',
  postgresql: false,
  mysql: false,
  mongodb: false,
  redis: false,
  disableRootLogin: false,
  disablePasswordAuth: false,
  changeSSHPort: false,
  sshPort: '2222',
  installFail2ban: false,
  setupFirewall: false,
  installSysmon: false,
  installNetdata: false,
  installNodeExporter: false,
  setupAlerts: false,
  installAwsCli: false,
  installDocker: false,
  installCertbot: false,
  setupGit: false,
  gitName: '',
  gitEmail: '',
}

function Toggle({ label, checked, onChange, indent }) {
  return (
    <label className={`flex items-center gap-3 py-2 cursor-pointer select-none text-sm ${indent ? 'pl-8' : ''}`}>
      <div
        onClick={(e) => { e.preventDefault(); onChange(!checked) }}
        className={`relative w-10 h-[22px] rounded-full shrink-0 cursor-pointer ${
          checked ? theme.toggleOn : theme.toggleOff
        }`}
      >
        <div
          className={`absolute top-[3px] left-[3px] w-4 h-4 ${theme.toggleKnob} rounded-full transition-transform ${
            checked ? 'translate-x-[18px]' : ''
          }`}
        />
      </div>
      <span className={theme.toggleLabel}>{label}</span>
    </label>
  )
}

function TextInput({ label, value, onChange, placeholder, indent }) {
  return (
    <div className={`flex items-center gap-3 py-2 text-sm ${indent ? 'pl-8' : ''}`}>
      <label className={`min-w-[100px] ${theme.inputLabel}`}>{label}</label>
      <input
        type="text"
        value={value}
        onChange={(e) => onChange(e.target.value)}
        placeholder={placeholder}
        className={`flex-1 px-3 py-2 rounded-lg text-sm ${theme.input}`}
      />
    </div>
  )
}

function RadioGroup({ label, options, value, onChange }) {
  return (
    <div className="py-2">
      <label className={`block ${theme.inputLabel} text-sm mb-2`}>{label}</label>
      <div className="flex gap-2 flex-wrap">
        {options.map((opt) => (
          <label
            key={opt.value}
            className={`flex items-center px-4 py-2 rounded-lg border cursor-pointer text-sm font-medium transition-all ${
              value === opt.value ? theme.radioSelected : theme.radioUnselected
            }`}
          >
            <input type="radio" name={label} value={opt.value} checked={value === opt.value}
              onChange={() => onChange(opt.value)} className="hidden" />
            {opt.label}
          </label>
        ))}
      </div>
    </div>
  )
}

function Select({ label, options, value, onChange, indent }) {
  return (
    <div className={`flex items-center gap-3 py-2 text-sm ${indent ? 'pl-8' : ''}`}>
      <label className={`min-w-[100px] ${theme.inputLabel}`}>{label}</label>
      <select value={value} onChange={(e) => onChange(e.target.value)}
        className={`flex-1 px-3 py-2 rounded-lg text-sm ${theme.select}`}>
        {options.map((opt) => (
          <option key={opt.value} value={opt.value}>{opt.label}</option>
        ))}
      </select>
    </div>
  )
}

function generateScript(c) {
  let s = `#!/bin/bash
set -e

# ============================================================
#  instaserver - Custom Setup Script
#  Generated at https://harshith-km.github.io/instaserver
#
#  Run: bash setup.sh
# ============================================================

# --- Colors ---
RED='\\033[0;31m'
GREEN='\\033[0;32m'
BLUE='\\033[0;34m'
BOLD='\\033[1m'
NC='\\033[0m'

step() { echo -e "\\n\${BLUE}[STEP]\${NC} \${BOLD}\$1\${NC}"; }
ok() { echo -e "\${GREEN}[OK]\${NC} \$1"; }
fail() { echo -e "\${RED}[ERROR]\${NC} \$1"; exit 1; }

# --- Detect OS ---
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ "$ID" == "ubuntu" || "$ID" == "debian" ]]; then
        PKG="apt"
    elif [[ "$ID" == "amzn" || "$ID" == "rhel" || "$ID" == "centos" || "$ID" == "fedora" ]]; then
        PKG="yum"
    else
        fail "Unsupported OS: $ID"
    fi
else
    fail "Cannot detect OS"
fi

ok "Detected OS: $ID ($VERSION_ID)"

pkg_install() {
    if [[ "$PKG" == "apt" ]]; then
        sudo apt-get install -y "$@"
    else
        sudo yum install -y "$@"
    fi
}
`

  if (c.updateSystem) {
    s += `
# ============================================================
#  Update System
# ============================================================
step "Updating system packages..."
if [[ "$PKG" == "apt" ]]; then
    sudo apt-get update -y && sudo apt-get upgrade -y
else
    sudo yum update -y
fi
ok "System updated."
`
  }

  s += `
# ============================================================
#  Install Common Tools
# ============================================================
step "Installing common utilities..."
if [[ "$PKG" == "apt" ]]; then
    pkg_install curl wget git unzip htop net-tools software-properties-common jq
else
    pkg_install curl wget git unzip htop net-tools jq
fi
ok "Common utilities installed."
`

  if (c.setupSwap) {
    s += `
# ============================================================
#  Swap File
# ============================================================
step "Setting up ${c.swapSize} swap file..."
if [ "$(swapon --show | wc -l)" -gt 0 ]; then
    ok "Swap already exists. Skipping."
else
    sudo fallocate -l ${c.swapSize} /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab > /dev/null
    echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf > /dev/null
    sudo sysctl vm.swappiness=10
    ok "${c.swapSize} swap configured."
fi
`
  }

  if (c.timezone) {
    s += `
# ============================================================
#  Timezone
# ============================================================
step "Setting timezone to ${c.timezone}..."
sudo timedatectl set-timezone ${c.timezone}
sudo timedatectl set-ntp true
ok "Timezone set."
`
  }

  if (c.backendRuntime === 'node') {
    s += `
# ============================================================
#  Node.js ${c.nodeVersion}
# ============================================================
step "Installing Node.js ${c.nodeVersion}..."
if [[ "$PKG" == "apt" ]]; then
    curl -fsSL "https://deb.nodesource.com/setup_${c.nodeVersion}.x" | sudo -E bash -
    sudo apt-get install -y nodejs
else
    curl -fsSL "https://rpm.nodesource.com/setup_${c.nodeVersion}.x" | sudo bash -
    sudo yum install -y nodejs
fi
sudo npm install -g npm@latest
ok "Node.js $(node -v) installed."
`
  }

  if (c.backendRuntime === 'python') {
    s += `
# ============================================================
#  Python
# ============================================================
step "Installing Python..."
if [[ "$PKG" == "apt" ]]; then
    pkg_install python3 python3-pip python3-venv
else
    pkg_install python3 python3-pip
fi
ok "Python $(python3 --version) installed."
`
  }

  if (c.installPm2 && c.backendRuntime === 'node') {
    s += `
# ============================================================
#  PM2
# ============================================================
step "Installing PM2..."
sudo npm install -g pm2
pm2 startup systemd -u "$USER" --hp "$HOME" | tail -1 | sudo bash - || true
ok "PM2 installed."
`
  }

  if (c.installDocker || c.backendRuntime === 'docker') {
    s += `
# ============================================================
#  Docker
# ============================================================
step "Installing Docker..."
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
ok "Docker installed."
`
  }

  if (c.installNginx) {
    s += `
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
ok "Nginx installed and running."
`
  }

  if (c.setupProxy && c.installNginx) {
    s += `
# ============================================================
#  Nginx Reverse Proxy -> localhost:${c.proxyPort}
# ============================================================
step "Configuring Nginx reverse proxy..."
sudo tee /etc/nginx/sites-available/app > /dev/null 2>/dev/null || sudo tee /etc/nginx/conf.d/app.conf > /dev/null <<'NGINXCONF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:${c.proxyPort};
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
NGINXCONF

if [[ "$PKG" == "apt" ]]; then
    sudo ln -sf /etc/nginx/sites-available/app /etc/nginx/sites-enabled/
    sudo rm -f /etc/nginx/sites-enabled/default
fi
sudo nginx -t && sudo systemctl reload nginx
ok "Reverse proxy -> localhost:${c.proxyPort}"
`
  }

  if (c.installCertbot) {
    s += `
# ============================================================
#  Certbot (SSL)
# ============================================================
step "Installing Certbot..."
if [[ "$PKG" == "apt" ]]; then
    pkg_install certbot python3-certbot-nginx
else
    pkg_install certbot python3-certbot-nginx || sudo pip3 install certbot certbot-nginx
fi
ok "Certbot installed. Run: sudo certbot --nginx -d yourdomain.com"
`
  }

  if (c.postgresql) {
    s += `
# ============================================================
#  PostgreSQL
# ============================================================
step "Installing PostgreSQL..."
if [[ "$PKG" == "apt" ]]; then
    pkg_install postgresql postgresql-contrib
else
    pkg_install postgresql-server postgresql
    sudo postgresql-setup --initdb 2>/dev/null || sudo postgresql-setup initdb
fi
sudo systemctl enable postgresql
sudo systemctl start postgresql
ok "PostgreSQL installed."
`
  }

  if (c.mysql) {
    s += `
# ============================================================
#  MySQL / MariaDB
# ============================================================
step "Installing MySQL..."
if [[ "$PKG" == "apt" ]]; then
    pkg_install mysql-server
    sudo systemctl enable mysql
    sudo systemctl start mysql
else
    pkg_install mariadb-server mariadb
    sudo systemctl enable mariadb
    sudo systemctl start mariadb
fi
ok "MySQL installed."
`
  }

  if (c.mongodb) {
    s += `
# ============================================================
#  MongoDB
# ============================================================
step "Installing MongoDB..."
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
ok "MongoDB installed."
`
  }

  if (c.redis) {
    s += `
# ============================================================
#  Redis
# ============================================================
step "Installing Redis..."
if [[ "$PKG" == "apt" ]]; then
    pkg_install redis-server
    sudo systemctl enable redis-server
    sudo systemctl start redis-server
else
    pkg_install redis
    sudo systemctl enable redis
    sudo systemctl start redis
fi
ok "Redis installed."
`
  }

  if (c.disableRootLogin || c.disablePasswordAuth || c.changeSSHPort) {
    s += `
# ============================================================
#  SSH Hardening
# ============================================================
step "Hardening SSH..."
`
    if (c.changeSSHPort) {
      s += `sudo sed -i "s/^#\\?Port .*/Port ${c.sshPort}/" /etc/ssh/sshd_config
`
    }
    if (c.disableRootLogin) {
      s += `sudo sed -i "s/^#\\?PermitRootLogin .*/PermitRootLogin no/" /etc/ssh/sshd_config
`
    }
    if (c.disablePasswordAuth) {
      s += `sudo sed -i "s/^#\\?PasswordAuthentication .*/PasswordAuthentication no/" /etc/ssh/sshd_config
`
    }
    s += `sudo systemctl restart sshd
ok "SSH hardened."
`
  }

  if (c.installFail2ban) {
    s += `
# ============================================================
#  Fail2Ban
# ============================================================
step "Installing Fail2Ban..."
if [[ "$PKG" == "apt" ]]; then
    pkg_install fail2ban
else
    pkg_install fail2ban || {
        sudo amazon-linux-extras install epel -y 2>/dev/null || true
        pkg_install fail2ban
    }
fi
sudo tee /etc/fail2ban/jail.local > /dev/null <<'F2BCONF'
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
F2BCONF
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
ok "Fail2Ban installed."
`
  }

  if (c.setupFirewall) {
    s += `
# ============================================================
#  Firewall
# ============================================================
step "Configuring firewall..."
if [[ "$PKG" == "apt" ]]; then
    pkg_install ufw
    sudo ufw allow OpenSSH
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
`
    if (c.changeSSHPort) {
      s += `    sudo ufw allow ${c.sshPort}/tcp
`
    }
    s += `    echo "y" | sudo ufw enable
    ok "UFW firewall enabled."
else
    sudo yum install -y firewalld 2>/dev/null || true
    sudo systemctl enable firewalld 2>/dev/null || true
    sudo systemctl start firewalld 2>/dev/null || true
    sudo firewall-cmd --permanent --add-service=ssh 2>/dev/null || true
    sudo firewall-cmd --permanent --add-service=http 2>/dev/null || true
    sudo firewall-cmd --permanent --add-service=https 2>/dev/null || true
    sudo firewall-cmd --reload 2>/dev/null || true
    ok "Firewall configured."
fi
`
  }

  if (c.installSysmon) {
    s += `
# ============================================================
#  System Monitoring Tools
# ============================================================
step "Installing monitoring tools..."
if [[ "$PKG" == "apt" ]]; then
    pkg_install htop iotop sysstat nmon ncdu
else
    pkg_install htop iotop sysstat nmon ncdu 2>/dev/null || pkg_install htop sysstat
fi
ok "Monitoring tools installed."
`
  }

  if (c.installNetdata) {
    s += `
# ============================================================
#  Netdata
# ============================================================
step "Installing Netdata..."
bash <(curl -Ss https://get.netdata.cloud/kickstart.sh) --dont-wait --no-updates 2>&1 || pkg_install netdata
sudo systemctl enable netdata 2>/dev/null || true
sudo systemctl start netdata 2>/dev/null || true
ok "Netdata running on port 19999."
`
  }

  if (c.installNodeExporter) {
    s += `
# ============================================================
#  Prometheus Node Exporter
# ============================================================
step "Installing Node Exporter..."
NE_VERSION="1.7.0"
ARCH=$(uname -m)
case $ARCH in x86_64) ARCH="amd64" ;; aarch64) ARCH="arm64" ;; esac
cd /tmp
wget -q "https://github.com/prometheus/node_exporter/releases/download/v\${NE_VERSION}/node_exporter-\${NE_VERSION}.linux-\${ARCH}.tar.gz"
tar xzf "node_exporter-\${NE_VERSION}.linux-\${ARCH}.tar.gz"
sudo mv "node_exporter-\${NE_VERSION}.linux-\${ARCH}/node_exporter" /usr/local/bin/
rm -rf "node_exporter-\${NE_VERSION}.linux-\${ARCH}"*
cd -
sudo useradd --no-create-home --shell /bin/false node_exporter 2>/dev/null || true
sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<'NESVC'
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
NESVC
sudo systemctl daemon-reload
sudo systemctl enable node_exporter
sudo systemctl start node_exporter
ok "Node Exporter running on port 9100."
`
  }

  if (c.setupAlerts) {
    s += `
# ============================================================
#  Resource Alerts (cron)
# ============================================================
step "Setting up resource alerts..."
sudo tee /usr/local/bin/ec2-resource-alert.sh > /dev/null <<'ALERTSCRIPT'
#!/bin/bash
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
LOG="/var/log/ec2-alerts.log"
HOST=$(hostname)
ALERT=0
CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print int($2 + $4)}')
MEM=$(free | awk '/Mem:/ {printf "%.0f", $3/$2 * 100}')
DISK=$(df / | awk 'NR==2 {print int($5)}')
[ "$CPU" -ge 90 ] && echo "[$TIMESTAMP] CPU: \${CPU}% on $HOST" >> "$LOG" && ALERT=1
[ "$MEM" -ge 85 ] && echo "[$TIMESTAMP] MEM: \${MEM}% on $HOST" >> "$LOG" && ALERT=1
[ "$DISK" -ge 80 ] && echo "[$TIMESTAMP] DISK: \${DISK}% on $HOST" >> "$LOG" && ALERT=1
[ "$ALERT" -eq 1 ] && ps aux --sort=-%mem | head -6 >> "$LOG"
ALERTSCRIPT
sudo chmod +x /usr/local/bin/ec2-resource-alert.sh
sudo touch /var/log/ec2-alerts.log
(sudo crontab -l 2>/dev/null | grep -v "ec2-resource-alert"; echo "*/5 * * * * /usr/local/bin/ec2-resource-alert.sh") | sudo crontab -
ok "Alert script runs every 5 min. Log: /var/log/ec2-alerts.log"
`
  }

  if (c.installAwsCli) {
    s += `
# ============================================================
#  AWS CLI v2
# ============================================================
step "Installing AWS CLI v2..."
ARCH=$(uname -m)
case $ARCH in x86_64) ARCH_URL="x86_64" ;; aarch64) ARCH_URL="aarch64" ;; esac
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-\${ARCH_URL}.zip" -o /tmp/awscliv2.zip
cd /tmp && unzip -qo awscliv2.zip && sudo ./aws/install --update && rm -rf aws awscliv2.zip && cd -
ok "AWS CLI $(aws --version) installed."
`
  }

  if (c.setupGit) {
    s += `
# ============================================================
#  Git Configuration
# ============================================================
step "Configuring Git..."
`
    if (c.gitName) s += `git config --global user.name "${c.gitName}"\n`
    if (c.gitEmail) s += `git config --global user.email "${c.gitEmail}"\n`
    s += `git config --global init.defaultBranch main
git config --global pull.rebase false
ok "Git configured."
`
  }

  s += `
# ============================================================
echo -e "\\n\${GREEN}\${BOLD}Setup complete!\${NC}"
echo -e "Run \${BLUE}sudo reboot\${NC} if needed for group/kernel changes."
`

  return s
}

export default function ScriptBuilder() {
  const [config, setConfig] = useState(DEFAULT_CONFIG)

  const update = (key, value) => {
    setConfig((prev) => ({ ...prev, [key]: value }))
  }

  const script = useMemo(() => generateScript(config), [config])

  const handleDownload = () => {
    const blob = new Blob([script], { type: 'text/x-shellscript' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = 'setup.sh'
    a.click()
    URL.revokeObjectURL(url)
  }

  const selectedCount = [
    config.updateSystem, config.setupSwap, config.timezone,
    config.backendRuntime !== 'none', config.installPm2, config.installNginx,
    config.setupProxy, config.postgresql, config.mysql, config.mongodb,
    config.redis, config.disableRootLogin, config.disablePasswordAuth,
    config.changeSSHPort, config.installFail2ban, config.setupFirewall,
    config.installSysmon, config.installNetdata, config.installNodeExporter,
    config.setupAlerts, config.installAwsCli, config.installDocker,
    config.installCertbot, config.setupGit,
  ].filter(Boolean).length

  return (
    <section className="px-4 sm:px-6 py-20 max-w-7xl mx-auto" id="builder">
      {/* Section header */}
      <div className="text-center mb-12 animate-fade-in-up">
        <div className={`inline-flex items-center justify-center w-12 h-12 rounded-2xl ${theme.accentBg} bg-opacity-10 mb-4`}>
          <Terminal size={24} className="text-white" />
        </div>
        <h2 className={`text-3xl sm:text-4xl font-bold mb-3 ${theme.heading}`}>Custom Script Builder</h2>
        <p className={`${theme.muted} text-lg max-w-md mx-auto`}>
          Toggle what you need. Your script updates live.
        </p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8 items-start">
        {/* Options - left side */}
        <div className="flex flex-col gap-4 animate-slide-left">
          <OptionGroup title="System Setup" delay={0}>
            <Toggle label="Update system packages" checked={config.updateSystem} onChange={(v) => update('updateSystem', v)} />
            <Toggle label="Setup swap file" checked={config.setupSwap} onChange={(v) => update('setupSwap', v)} />
            {config.setupSwap && (
              <Select label="Swap size" indent value={config.swapSize} onChange={(v) => update('swapSize', v)}
                options={[{ value: '1G', label: '1 GB' }, { value: '2G', label: '2 GB' }, { value: '4G', label: '4 GB' }]} />
            )}
            <TextInput label="Timezone" value={config.timezone} onChange={(v) => update('timezone', v)} placeholder="e.g. Asia/Kolkata, UTC" />
          </OptionGroup>

          <OptionGroup title="Hosting" delay={1}>
            <RadioGroup label="Backend runtime" value={config.backendRuntime} onChange={(v) => update('backendRuntime', v)}
              options={[{ value: 'none', label: 'None' }, { value: 'node', label: 'Node.js' }, { value: 'python', label: 'Python' }, { value: 'docker', label: 'Docker' }]} />
            {config.backendRuntime === 'node' && (
              <>
                <Select label="Node version" indent value={config.nodeVersion} onChange={(v) => update('nodeVersion', v)}
                  options={[{ value: '18', label: 'Node 18 LTS' }, { value: '20', label: 'Node 20 LTS' }, { value: '22', label: 'Node 22 LTS' }]} />
                <Toggle label="Install PM2" checked={config.installPm2} onChange={(v) => update('installPm2', v)} indent />
              </>
            )}
            <Toggle label="Install Nginx" checked={config.installNginx} onChange={(v) => update('installNginx', v)} />
            {config.installNginx && (
              <>
                <Toggle label="Setup reverse proxy" checked={config.setupProxy} onChange={(v) => update('setupProxy', v)} indent />
                {config.setupProxy && (
                  <TextInput label="App port" value={config.proxyPort} onChange={(v) => update('proxyPort', v)} placeholder="3000" indent />
                )}
              </>
            )}
          </OptionGroup>

          <OptionGroup title="Database" delay={2}>
            <Toggle label="PostgreSQL" checked={config.postgresql} onChange={(v) => update('postgresql', v)} />
            <Toggle label="MySQL / MariaDB" checked={config.mysql} onChange={(v) => update('mysql', v)} />
            <Toggle label="MongoDB" checked={config.mongodb} onChange={(v) => update('mongodb', v)} />
            <Toggle label="Redis" checked={config.redis} onChange={(v) => update('redis', v)} />
          </OptionGroup>

          <OptionGroup title="SSH & Security" delay={3}>
            <Toggle label="Disable root login" checked={config.disableRootLogin} onChange={(v) => update('disableRootLogin', v)} />
            <Toggle label="Disable password auth" checked={config.disablePasswordAuth} onChange={(v) => update('disablePasswordAuth', v)} />
            <Toggle label="Change SSH port" checked={config.changeSSHPort} onChange={(v) => update('changeSSHPort', v)} />
            {config.changeSSHPort && (
              <TextInput label="SSH port" value={config.sshPort} onChange={(v) => update('sshPort', v)} placeholder="2222" indent />
            )}
            <Toggle label="Install Fail2Ban" checked={config.installFail2ban} onChange={(v) => update('installFail2ban', v)} />
            <Toggle label="Setup firewall (UFW/firewalld)" checked={config.setupFirewall} onChange={(v) => update('setupFirewall', v)} />
          </OptionGroup>

          <OptionGroup title="Monitoring" delay={4}>
            <Toggle label="htop, sysstat, nmon, ncdu" checked={config.installSysmon} onChange={(v) => update('installSysmon', v)} />
            <Toggle label="Netdata (web dashboard)" checked={config.installNetdata} onChange={(v) => update('installNetdata', v)} />
            <Toggle label="Prometheus Node Exporter" checked={config.installNodeExporter} onChange={(v) => update('installNodeExporter', v)} />
            <Toggle label="CPU/Memory/Disk alerts (cron)" checked={config.setupAlerts} onChange={(v) => update('setupAlerts', v)} />
          </OptionGroup>

          <OptionGroup title="Other" delay={5}>
            <Toggle label="AWS CLI v2" checked={config.installAwsCli} onChange={(v) => update('installAwsCli', v)} />
            <Toggle label="Docker" checked={config.installDocker} onChange={(v) => update('installDocker', v)} />
            <Toggle label="Certbot (SSL)" checked={config.installCertbot} onChange={(v) => update('installCertbot', v)} />
            <Toggle label="Configure Git" checked={config.setupGit} onChange={(v) => update('setupGit', v)} />
            {config.setupGit && (
              <>
                <TextInput label="Git name" value={config.gitName} onChange={(v) => update('gitName', v)} placeholder="Your Name" indent />
                <TextInput label="Git email" value={config.gitEmail} onChange={(v) => update('gitEmail', v)} placeholder="you@example.com" indent />
              </>
            )}
          </OptionGroup>
        </div>

        {/* Preview - right side */}
        <div className={`sticky top-4 ${theme.previewContainer} rounded-xl overflow-hidden animate-slide-right`}>
          {/* Preview header with actions */}
          <div className={`${theme.previewHeader} px-4 py-3`}>
            <div className="flex items-center justify-between flex-wrap gap-3">
              <div className={`flex items-center gap-2 ${theme.previewHeaderText} text-sm font-medium`}>
                <div className="flex gap-1.5">
                  <span className="w-3 h-3 rounded-full bg-red-400/80" />
                  <span className="w-3 h-3 rounded-full bg-yellow-400/80" />
                  <span className="w-3 h-3 rounded-full bg-green-400/80" />
                </div>
                <span className="ml-2">setup.sh</span>
                <span className={`${theme.optionCountBadge} px-2.5 py-0.5 rounded-full text-xs font-semibold`}>
                  {selectedCount} selected
                </span>
              </div>
              <div className="flex gap-2">
                <CopyButton text={script} label="Copy" />
                <button
                  onClick={handleDownload}
                  className={`inline-flex items-center gap-1.5 px-3 py-1.5 text-sm font-medium rounded-lg border ${theme.btnAction}`}
                >
                  <Download size={14} />
                  Download
                </button>
              </div>
            </div>
          </div>
          {/* Code output */}
          <pre className={`p-4 overflow-auto max-h-[75vh] lg:max-h-[82vh] font-mono text-xs leading-relaxed ${theme.codeText} preview-scroll`}>
            <code>{script}</code>
          </pre>
        </div>
      </div>
    </section>
  )
}

function OptionGroup({ title, children }) {
  return (
    <div className={`${theme.optionGroup} rounded-xl p-5`}>
      <h3 className={`text-xs uppercase tracking-widest font-semibold mb-4 pb-2.5 ${theme.optionGroupTitle}`}>
        {title}
      </h3>
      <div className="space-y-0.5">
        {children}
      </div>
    </div>
  )
}
