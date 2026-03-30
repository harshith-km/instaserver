#!/bin/bash

# ============================================================
#  instaserver - Server Snapshot Tool
#  https://github.com/harshith-km/instaserver
#
#  Takes a complete snapshot of your server's current state
#  and generates a reinstall script to replicate it.
#
#  Usage:
#    bash <(curl -fsSL https://raw.githubusercontent.com/harshith-km/instaserver/main/snapshot.sh)
#
#  Output: ~/server-snapshot-YYYYMMDD-HHMMSS/
# ============================================================

set -e

# --- All modules ---
SNAP_MODULES=(
    common.sh
    system.sh
    projects.sh
    webserver.sh
    database.sh
    docker.sh
    pm2.sh
    security.sh
    env.sh
    cron.sh
    server-config.sh
    reinstall.sh
)

# --- Resolve module directory ---
SCRIPT_DIR=""

resolve_snap_modules() {
    if [[ -d "./snapshot-modules" ]]; then
        SCRIPT_DIR="."
        return
    fi

    SCRIPT_DIR=$(mktemp -d)
    MODULES_BASE="https://raw.githubusercontent.com/harshith-km/instaserver/main/snapshot-modules"

    mkdir -p "$SCRIPT_DIR/snapshot-modules"
    echo "Downloading snapshot modules..."
    for mod in "${SNAP_MODULES[@]}"; do
        curl -fsSL "$MODULES_BASE/$mod" -o "$SCRIPT_DIR/snapshot-modules/$mod" || {
            echo "Failed to download $mod"
            exit 1
        }
    done
    echo "Done."
}

resolve_snap_modules

# --- Source all modules ---
for mod in "${SNAP_MODULES[@]}"; do
    source "$SCRIPT_DIR/snapshot-modules/$mod"
done

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
#  Run all scans
# ============================================================

# 1. System info, packages, services
snap_system_info
snap_packages
snap_services

# 2. Projects & directory structure
snap_projects
snap_directory_tree

# 3. Web server configs
snap_nginx
snap_apache
snap_ssl

# 4. Databases
snap_databases

# 5. Docker
snap_docker

# 6. PM2
snap_pm2

# 7. Security
snap_ssh
snap_firewall
snap_users

# 8. Environment & shell
snap_env_files
snap_shell_config

# 9. Cron, timers, logrotate
snap_cron
snap_systemd_timers
snap_logrotate

# 10. Server-only config (not in git)
snap_global_packages
snap_sysctl
snap_network
snap_disk_mounts
snap_aws_info
snap_systemd_services

# 11. Generate reinstall script
snap_generate_reinstall

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
echo -e "    7. Restore shell config from ${CYAN}shell-config/${NC}"
echo ""

# Cleanup temp dir if used
[[ "$SCRIPT_DIR" == /tmp/* ]] && rm -rf "$SCRIPT_DIR"
