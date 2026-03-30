# instaserver

One-command interactive setup script for fresh EC2 instances (Ubuntu Server / Amazon Linux).

No cloning, no downloading files manually. Just SSH into your new instance and run:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/harshith-km/instaserver/main/setup.sh)
```

Or with `wget`:

```bash
bash <(wget -qO- https://raw.githubusercontent.com/harshith-km/instaserver/main/setup.sh)
```

### Headless mode (for AMIs / EC2 user-data)

```bash
# Generate a config file interactively
bash <(curl -fsSL https://raw.githubusercontent.com/harshith-km/instaserver/main/setup.sh) --generate-config

# Run with the config (no prompts)
bash <(curl -fsSL https://raw.githubusercontent.com/harshith-km/instaserver/main/setup.sh) --headless instaserver.conf
```

### Quick flags

```bash
--sysinfo          # Print system info dashboard
--security-check   # Run security audit
--export           # Export server config
--update           # Update instaserver to latest
```

---

## What it does

An interactive, menu-driven script with 25 options across 21 modules.

```
╔═══════════════════════════════════════════════════╗
║              instaserver - Main Menu              ║
╠═══════════════════════════════════════════════════╣
║  Hosting                                          ║
   1) Backend hosting setup
   2) Frontend hosting setup
   3) Full stack (Backend + Frontend)
   4) Multi-site Nginx manager
║  Server Setup                                     ║
   5) SSH setup & hardening
   6) Firewall setup
   7) Database setup
   8) Install Docker
   9) Install Certbot (SSL)
║  Development                                      ║
  10) Git configuration
  11) App deployment (Git clone, CI/CD runner)
  12) Environment file (.env) manager
║  AWS                                              ║
  13) AWS CLI & tools setup
  14) Backup setup (DB, files, S3)
║  Monitoring & Security                            ║
  15) Monitoring, logging & alerts
  16) Security scan & hardening
  17) System info & log viewer
║  DNS & Domain                                     ║
  18) DNS & domain tools
║  Shell & System                                   ║
  19) Customize .bashrc
  20) Timezone & locale
  21) Cron job manager
║  Maintenance                                      ║
  22) Export / import server config
  23) Cleanup & uninstall
  24) Update instaserver
  25) Generate headless config
╚═══════════════════════════════════════════════════╝
```

---

## Features

### Hosting
- **Backend**: Node.js (18/20/22) + PM2, Python + venv, Docker
- **Frontend**: Static sites (React/Vue/Angular) with Nginx, SSR apps (Next.js/Nuxt) with PM2
- **Multi-site**: Add/remove/enable/disable multiple Nginx virtual hosts, reverse proxy & static
- Nginx reverse proxy with WebSocket support, gzip, caching
- SSL via Let's Encrypt (Certbot)

### SSH Hardening
- Change SSH port, disable root login & password auth
- Add SSH public keys, create sudo users
- Fail2Ban (auto-ban after 5 failed attempts)
- Idle timeout config, full hardening preset

### Database
- PostgreSQL, MySQL/MariaDB, MongoDB, Redis

### Monitoring & Security
| Type | Tools |
|------|-------|
| CLI monitors | htop, iotop, sysstat, nmon, ncdu, glances, ctop |
| Web dashboards | Netdata (port 19999), Grafana (port 3000) |
| Metrics | Prometheus Node Exporter (port 9100) |
| Log management | Logrotate, GoAccess (Nginx/Apache analyzer) |
| AWS | CloudWatch Agent |
| Security | Lynis audit, nmap self-scan, CIS benchmark checks |
| Alerts | CPU/memory/disk threshold alerts via cron + optional email |

### Security Scanning
- Port scan (self-scan with nmap)
- SSH, firewall, unattended upgrades, Fail2Ban checks
- Weak config detection (default DB passwords, Redis without auth, etc.)
- Basic CIS benchmark scoring

### AWS Tools
- AWS CLI v2 install & configure
- Named profiles
- SSM Session Manager plugin
- S3 bucket setup
- CloudFormation helper scripts

### App Deployment
- Clone repo, detect project type, install deps, set up PM2/systemd
- GitHub Actions self-hosted runner
- Deploy keys for GitHub

### Backup
- Database backups (PostgreSQL, MySQL, MongoDB) with retention
- File/directory backups with tar+gzip
- S3 sync (full or incremental)
- Full server snapshot (all DBs + configs + app files)
- Cron scheduling for all backup types

### DNS & Domain
- DNS propagation check across multiple resolvers
- Domain-to-server verification
- HTTP/HTTPS connectivity testing
- DNS record lookup (A, AAAA, MX, CNAME, TXT, NS)
- Hostname configuration

### Environment Files
- Create/edit/view .env files
- Masked secret display
- Encryption with age

### Cron Jobs
- Interactive cron job manager (add/list/remove)
- Presets: tmp cleanup, log cleanup, health check, DB backup, SSL renewal, S3 backup

### Shell Customization (.bashrc)
- Useful aliases (docker, pm2, systemd, nginx, navigation)
- PS1 prompt with git branch (3 styles)
- Environment variables, PATH entries, default editor
- History improvements (10k entries, timestamps, dedup)
- Full preset with system info on login

### System Info
- Dashboard: IP, disk, RAM, CPU, uptime, load
- Running services, open ports
- Process viewer (by CPU or memory)
- Live log viewer (Nginx, syslog, PM2, Docker, custom)

### Maintenance
- Export server config (readable report + reusable headless config)
- Import/replicate config on another instance
- Cleanup & uninstall (Nginx, Node, Docker, databases, monitoring)
- Self-update from GitHub

### Other
- Swap file setup (1G/2G/4G/custom) with optimized swappiness
- Timezone & NTP sync
- Git config + SSH key generation
- UFW / firewalld firewall

---

## Project Structure

```
instaserver/
├── setup.sh              # Entry point - sources modules, main menu, CLI flags
├── VERSION               # Current version (semver)
└── modules/
    ├── common.sh         # Colors, helpers, OS detection, swap, firewall
    ├── ssh.sh            # SSH hardening, Fail2Ban, user management
    ├── database.sh       # PostgreSQL, MySQL, MongoDB, Redis
    ├── monitoring.sh     # Netdata, Grafana, Prometheus, alerts, Lynis
    ├── webserver.sh      # Nginx, Node.js, PM2, Docker, Python, SSL
    ├── hosting.sh        # Backend, frontend & full stack setup flows
    ├── git.sh            # Git config, SSH key generation
    ├── bashrc.sh         # Aliases, prompt, history, env vars
    ├── aws.sh            # AWS CLI, profiles, SSM, S3, CloudFormation
    ├── deploy.sh         # Git deploy, GitHub Actions runner, deploy keys
    ├── cron.sh           # Cron job manager with presets
    ├── backup.sh         # DB/file/S3 backups, server snapshots
    ├── multisite.sh      # Multi-site Nginx virtual host manager
    ├── envfile.sh        # .env file manager with encryption
    ├── dns.sh            # DNS propagation, domain verification, lookups
    ├── sysinfo.sh        # System dashboard, log viewer, process monitor
    ├── security.sh       # Port scan, security audit, CIS checks
    ├── cleanup.sh        # Uninstall & cleanup
    ├── headless.sh       # Non-interactive mode with config files
    ├── selfupdate.sh     # Self-update from GitHub
    └── export.sh         # Export/import server configuration
```

When run via `curl`, modules are auto-downloaded to a temp directory. When cloned locally, it uses the local `modules/` folder directly.

**Adding a new feature?** Create a module in `modules/`, add it to the `MODULES` array in `setup.sh`, and add a menu entry.

---

## Supported OS

| OS | Package Manager | Tested |
|----|----------------|--------|
| Ubuntu Server 20.04+ | apt | Yes |
| Debian 11+ | apt | Yes |
| Amazon Linux 2 / 2023 | yum | Yes |
| RHEL / CentOS / Fedora | yum | Yes |

---

## Usage Tips

- Run with `sudo` privileges (the script calls `sudo` internally)
- The menu loops - set up multiple things in one session
- `.bashrc` changes are backed up automatically before modification
- After SSH hardening, **test in a new terminal before closing your session**
- Use `--headless` mode for automated/repeatable setups
- Use `--export` to snapshot your config and replicate on other instances

## License

MIT
