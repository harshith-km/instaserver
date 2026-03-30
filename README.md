# instaserver

One-command interactive setup script for fresh EC2 instances (Ubuntu Server / Amazon Linux).

No cloning, no downloading files manually. Just SSH into your new instance and run:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/harshith-km/instaserver/main/ec2-setup.sh)
```

Or with `wget`:

```bash
bash <(wget -qO- https://raw.githubusercontent.com/harshith-km/instaserver/main/ec2-setup.sh)
```

---

## What it does

An interactive, menu-driven script that detects your OS automatically and installs everything you need.

```
╔══════════════════════════════════════════╗
║            Main Menu                     ║
╚══════════════════════════════════════════╝
   1) Backend hosting setup
   2) Frontend hosting setup
   3) Full stack (Backend + Frontend)
   4) SSH setup & hardening
   5) Database setup
   6) Git configuration
   7) Customize .bashrc
   8) Timezone & locale
   9) Monitoring, logging & security tools
  10) Firewall setup
  11) Install Docker
  12) Install Certbot (SSL)
   0) Exit
```

### Backend Hosting
- **Node.js** (18 / 20 / 22 LTS) + PM2 process manager
- **Python** (pip, venv) for Flask / FastAPI / Django
- **Docker** + Docker Compose
- Nginx reverse proxy with WebSocket support
- SSL via Let's Encrypt

### Frontend Hosting
- **Static sites** (React / Vue / Angular) with Nginx, gzip, caching headers
- **SSR apps** (Next.js / Nuxt.js) with PM2 + Nginx reverse proxy
- SSL via Let's Encrypt

### SSH Hardening
- Change SSH port
- Disable root login & password auth
- Add SSH public keys
- Create sudo users
- Fail2Ban (auto-ban after 5 failed attempts)
- Idle timeout config

### Database
- PostgreSQL
- MySQL / MariaDB
- MongoDB
- Redis

### Monitoring & Security
| Type | Tools |
|------|-------|
| CLI monitors | htop, iotop, sysstat, nmon, ncdu, glances, ctop |
| Web dashboards | Netdata (port 19999), Grafana (port 3000) |
| Metrics | Prometheus Node Exporter (port 9100) |
| Log management | Logrotate, GoAccess (Nginx/Apache analyzer) |
| AWS | CloudWatch Agent |
| Security | Lynis audit, auto security updates, Fail2Ban |
| Alerts | CPU/memory/disk threshold alerts via cron + optional email |

### Shell Customization (.bashrc)
- Useful aliases (docker, pm2, systemd, nginx, navigation)
- PS1 prompt with git branch (3 styles)
- Environment variables, PATH entries, default editor
- History improvements (10k entries, timestamps, dedup)
- Full preset with system info on login

### Other
- Swap file setup (1G / 2G / 4G / custom) with optimized swappiness
- Timezone & NTP sync
- Git config + SSH key generation
- UFW / firewalld firewall

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

## License

MIT
