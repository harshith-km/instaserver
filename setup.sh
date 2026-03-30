#!/bin/bash

# ============================================================
#  instaserver v1.0.0 - Interactive EC2 Setup Script
#  https://github.com/harshith-km/instaserver
#
#  Usage:
#    bash <(curl -fsSL https://raw.githubusercontent.com/harshith-km/instaserver/main/setup.sh)
#
#  Headless mode:
#    bash <(curl -fsSL https://raw.githubusercontent.com/harshith-km/instaserver/main/setup.sh) --headless config.conf
# ============================================================

set -e

INSTASERVER_VERSION="1.0.0"

# --- All modules ---
MODULES=(
    common.sh
    ssh.sh
    database.sh
    monitoring.sh
    webserver.sh
    hosting.sh
    git.sh
    bashrc.sh
    aws.sh
    deploy.sh
    cron.sh
    backup.sh
    multisite.sh
    envfile.sh
    dns.sh
    sysinfo.sh
    security.sh
    cleanup.sh
    headless.sh
    selfupdate.sh
    export.sh
)

# --- Resolve script directory (works with curl pipe too) ---
SCRIPT_DIR=""

resolve_modules() {
    # If running from a cloned repo, use local modules
    if [[ -d "./modules" ]]; then
        SCRIPT_DIR="."
        return
    fi

    # If piped via curl, download modules to a temp dir
    SCRIPT_DIR=$(mktemp -d)
    MODULES_BASE="https://raw.githubusercontent.com/harshith-km/instaserver/main/modules"

    mkdir -p "$SCRIPT_DIR/modules"
    echo "Downloading instaserver modules..."
    for mod in "${MODULES[@]}"; do
        curl -fsSL "$MODULES_BASE/$mod" -o "$SCRIPT_DIR/modules/$mod" || {
            echo "Failed to download $mod"
            exit 1
        }
    done
    echo "Done."
}

resolve_modules

# --- Source all modules ---
for mod in "${MODULES[@]}"; do
    source "$SCRIPT_DIR/modules/$mod"
done

# ============================================================
#  MAIN MENU
# ============================================================
main() {
    # Handle CLI flags
    if [[ "$1" == "--headless" && -n "$2" ]]; then
        detect_os
        run_headless "$2"
        exit 0
    fi

    if [[ "$1" == "--generate-config" ]]; then
        generate_config
        exit 0
    fi

    if [[ "$1" == "--update" ]]; then
        detect_os
        self_update
        exit 0
    fi

    if [[ "$1" == "--export" ]]; then
        detect_os
        export_config
        exit 0
    fi

    if [[ "$1" == "--sysinfo" ]]; then
        detect_os
        sysinfo_summary
        exit 0
    fi

    if [[ "$1" == "--security-check" ]]; then
        detect_os
        security_check
        exit 0
    fi

    print_banner
    echo -e "  ${BOLD}Version:${NC} $INSTASERVER_VERSION"
    detect_os

    # Check for updates (non-blocking)
    check_update 2>/dev/null || true

    # Initial system setup
    if confirm "Update system packages?"; then
        pkg_update
    fi

    if confirm "Set up swap file? (recommended for small instances)"; then
        setup_swap
    fi

    install_common

    # Loop menu
    while true; do
        echo -e "\n${BOLD}╔═══════════════════════════════════════════════════╗${NC}"
        echo -e "${BOLD}║              instaserver - Main Menu              ║${NC}"
        echo -e "${BOLD}╠═══════════════════════════════════════════════════╣${NC}"
        echo -e "${BOLD}║  ${CYAN}Hosting${NC}${BOLD}                                          ║${NC}"
        echo -e "   1) Backend hosting setup"
        echo -e "   2) Frontend hosting setup"
        echo -e "   3) Full stack (Backend + Frontend)"
        echo -e "   4) Multi-site Nginx manager"
        echo -e "${BOLD}║  ${CYAN}Server Setup${NC}${BOLD}                                      ║${NC}"
        echo -e "   5) SSH setup & hardening"
        echo -e "   6) Firewall setup"
        echo -e "   7) Database setup"
        echo -e "   8) Install Docker"
        echo -e "   9) Install Certbot (SSL)"
        echo -e "${BOLD}║  ${CYAN}Development${NC}${BOLD}                                       ║${NC}"
        echo -e "  10) Git configuration"
        echo -e "  11) App deployment (Git clone, CI/CD runner)"
        echo -e "  12) Environment file (.env) manager"
        echo -e "${BOLD}║  ${CYAN}AWS${NC}${BOLD}                                               ║${NC}"
        echo -e "  13) AWS CLI & tools setup"
        echo -e "  14) Backup setup (DB, files, S3)"
        echo -e "${BOLD}║  ${CYAN}Monitoring & Security${NC}${BOLD}                              ║${NC}"
        echo -e "  15) Monitoring, logging & alerts"
        echo -e "  16) Security scan & hardening"
        echo -e "  17) System info & log viewer"
        echo -e "${BOLD}║  ${CYAN}DNS & Domain${NC}${BOLD}                                      ║${NC}"
        echo -e "  18) DNS & domain tools"
        echo -e "${BOLD}║  ${CYAN}Shell & System${NC}${BOLD}                                    ║${NC}"
        echo -e "  19) Customize .bashrc"
        echo -e "  20) Timezone & locale"
        echo -e "  21) Cron job manager"
        echo -e "${BOLD}║  ${CYAN}Maintenance${NC}${BOLD}                                       ║${NC}"
        echo -e "  22) Export / import server config"
        echo -e "  23) Cleanup & uninstall"
        echo -e "  24) Update instaserver"
        echo -e "  25) Generate headless config"
        echo -e "${BOLD}╠═══════════════════════════════════════════════════╣${NC}"
        echo -e "   0) Exit"
        echo -e "${BOLD}╚═══════════════════════════════════════════════════╝${NC}"
        echo -e ""
        read -rp "Choice [0-25]: " menu_choice

        case $menu_choice in
            1)  setup_backend ;;
            2)  setup_frontend ;;
            3)  setup_fullstack ;;
            4)  setup_multisite ;;
            5)  setup_ssh ;;
            6)  setup_firewall ;;
            7)  setup_database ;;
            8)  install_docker ;;
            9)  install_certbot ;;
            10) setup_git ;;
            11) setup_deploy ;;
            12) setup_envfile ;;
            13) setup_aws ;;
            14) setup_backup ;;
            15) setup_monitoring ;;
            16) setup_security ;;
            17) setup_sysinfo ;;
            18) setup_dns ;;
            19) setup_bashrc ;;
            20) setup_timezone ;;
            21) setup_cron ;;
            22) setup_export ;;
            23) setup_cleanup ;;
            24) self_update ;;
            25) generate_config ;;
            0)
                echo -e "\n${GREEN}${BOLD}All done!${NC} Your EC2 instance is ready."
                echo -e "Run ${CYAN}source ~/.bashrc${NC} to apply shell changes."
                echo -e "Run ${CYAN}sudo reboot${NC} if needed for group/kernel changes.\n"
                # Cleanup temp dir if used
                [[ "$SCRIPT_DIR" == /tmp/* ]] && rm -rf "$SCRIPT_DIR"
                exit 0
                ;;
            *)
                print_error "Invalid choice. Try again."
                ;;
        esac
    done
}

main "$@"
