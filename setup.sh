#!/bin/bash

# ============================================================
#  instaserver - Interactive EC2 Setup Script
#  https://github.com/harshith-km/instaserver
#
#  Usage:
#    bash <(curl -fsSL https://raw.githubusercontent.com/harshith-km/instaserver/main/setup.sh)
# ============================================================

set -e

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
    echo "Downloading modules..."
    for mod in common.sh ssh.sh database.sh monitoring.sh webserver.sh hosting.sh git.sh bashrc.sh; do
        curl -fsSL "$MODULES_BASE/$mod" -o "$SCRIPT_DIR/modules/$mod" || {
            echo "Failed to download $mod"
            exit 1
        }
    done
    echo "Done."
}

resolve_modules

# --- Source all modules ---
source "$SCRIPT_DIR/modules/common.sh"
source "$SCRIPT_DIR/modules/ssh.sh"
source "$SCRIPT_DIR/modules/database.sh"
source "$SCRIPT_DIR/modules/monitoring.sh"
source "$SCRIPT_DIR/modules/webserver.sh"
source "$SCRIPT_DIR/modules/hosting.sh"
source "$SCRIPT_DIR/modules/git.sh"
source "$SCRIPT_DIR/modules/bashrc.sh"

# ============================================================
#  MAIN MENU
# ============================================================
main() {
    print_banner
    detect_os

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
        echo -e "\n${BOLD}╔══════════════════════════════════════════╗${NC}"
        echo -e "${BOLD}║            Main Menu                     ║${NC}"
        echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}"
        echo -e "   1) Backend hosting setup"
        echo -e "   2) Frontend hosting setup"
        echo -e "   3) Full stack (Backend + Frontend)"
        echo -e "   4) SSH setup & hardening"
        echo -e "   5) Database setup"
        echo -e "   6) Git configuration"
        echo -e "   7) Customize .bashrc"
        echo -e "   8) Timezone & locale"
        echo -e "   9) Monitoring, logging & security tools"
        echo -e "  10) Firewall setup"
        echo -e "  11) Install Docker"
        echo -e "  12) Install Certbot (SSL)"
        echo -e "   0) Exit"
        echo -e ""
        read -rp "Choice [0-12]: " menu_choice

        case $menu_choice in
            1)  setup_backend ;;
            2)  setup_frontend ;;
            3)  setup_fullstack ;;
            4)  setup_ssh ;;
            5)  setup_database ;;
            6)  setup_git ;;
            7)  setup_bashrc ;;
            8)  setup_timezone ;;
            9)  setup_monitoring ;;
            10) setup_firewall ;;
            11) install_docker ;;
            12) install_certbot ;;
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

main
