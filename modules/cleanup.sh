#!/bin/bash
# ============================================================
#  Cleanup: Uninstall & remove things installed by instaserver
# ============================================================

setup_cleanup() {
    echo -e "\n${CYAN}── Cleanup / Uninstall ──${NC}"

    echo -e "\n  Select what to remove:"
    echo -e "    1) Remove Nginx"
    echo -e "    2) Remove Node.js & PM2"
    echo -e "    3) Remove Docker"
    echo -e "    4) Remove database (PostgreSQL / MySQL / MongoDB / Redis)"
    echo -e "    5) Remove monitoring tools (Netdata / Grafana / Node Exporter)"
    echo -e "    6) Remove Fail2Ban"
    echo -e "    7) Clean package cache"
    echo -e "    8) Remove unused packages (autoremove)"
    echo -e "    9) Full cleanup (everything above)"
    echo -e "    0) Back to main menu"
    read -rp "  Choice [0-9]: " cleanup_choice

    case $cleanup_choice in
        1) cleanup_nginx ;;
        2) cleanup_node ;;
        3) cleanup_docker ;;
        4) cleanup_database ;;
        5) cleanup_monitoring ;;
        6) cleanup_fail2ban ;;
        7) cleanup_cache ;;
        8) cleanup_autoremove ;;
        9)
            if confirm "  This will remove ALL installed components. Are you sure?"; then
                cleanup_nginx
                cleanup_node
                cleanup_docker
                cleanup_database_all
                cleanup_monitoring
                cleanup_fail2ban
                cleanup_cache
                cleanup_autoremove
                print_success "Full cleanup complete."
            fi
            ;;
        0) return ;;
        *) print_error "Invalid choice."; return ;;
    esac
}

# --- Nginx ---
cleanup_nginx() {
    if ! confirm "  Remove Nginx and all its configuration?"; then
        return
    fi

    print_step "Removing Nginx..."
    sudo systemctl stop nginx 2>/dev/null || true
    sudo systemctl disable nginx 2>/dev/null || true

    if [[ "$PKG" == "apt" ]]; then
        sudo apt-get purge -y nginx nginx-common nginx-full 2>/dev/null || true
    else
        sudo yum remove -y nginx 2>/dev/null || true
    fi

    sudo rm -rf /etc/nginx/sites-available/* 2>/dev/null || true
    sudo rm -rf /etc/nginx/sites-enabled/* 2>/dev/null || true
    sudo rm -rf /etc/nginx/conf.d/* 2>/dev/null || true

    print_success "Nginx removed and configuration cleaned."
}

# --- Node.js & PM2 ---
cleanup_node() {
    if ! confirm "  Remove Node.js, npm, and PM2?"; then
        return
    fi

    print_step "Removing Node.js & PM2..."

    # Stop PM2 first
    if command -v pm2 &>/dev/null; then
        pm2 kill 2>/dev/null || true
        sudo npm uninstall -g pm2 2>/dev/null || true
        print_success "PM2 stopped and removed."
    fi

    if [[ "$PKG" == "apt" ]]; then
        sudo apt-get purge -y nodejs 2>/dev/null || true
        # Remove nodesource repo
        sudo rm -f /etc/apt/sources.list.d/nodesource.list 2>/dev/null || true
        sudo rm -f /etc/apt/keyrings/nodesource.gpg 2>/dev/null || true
        sudo apt-get update -y 2>/dev/null || true
    else
        sudo yum remove -y nodejs 2>/dev/null || true
        sudo rm -f /etc/yum.repos.d/nodesource*.repo 2>/dev/null || true
    fi

    print_success "Node.js and npm removed."
}

# --- Docker ---
cleanup_docker() {
    if ! confirm "  Remove Docker? Running containers will be stopped."; then
        return
    fi

    print_step "Removing Docker..."

    # Stop all running containers
    if command -v docker &>/dev/null; then
        sudo docker stop $(sudo docker ps -aq) 2>/dev/null || true
        sudo docker rm $(sudo docker ps -aq) 2>/dev/null || true
    fi

    if [[ "$PKG" == "apt" ]]; then
        sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-compose-plugin docker-buildx-plugin 2>/dev/null || true
        sudo rm -f /etc/apt/sources.list.d/docker.list 2>/dev/null || true
        sudo rm -f /etc/apt/keyrings/docker.gpg 2>/dev/null || true
    else
        sudo yum remove -y docker 2>/dev/null || true
    fi

    if confirm "  ${RED}Remove all Docker data (/var/lib/docker)? This deletes all images, volumes, and containers.${NC}"; then
        sudo rm -rf /var/lib/docker
        sudo rm -rf /var/lib/containerd
        print_success "Docker data removed."
    fi

    print_success "Docker removed."
}

# --- Database ---
cleanup_database() {
    echo -e "\n${CYAN}── Remove Database ──${NC}"

    echo -e "\n  Select database to remove:"
    echo -e "    1) PostgreSQL"
    echo -e "    2) MySQL / MariaDB"
    echo -e "    3) MongoDB"
    echo -e "    4) Redis"
    echo -e "    5) Back"
    read -rp "  Choice [1-5]: " db_choice

    case $db_choice in
        1) cleanup_postgresql ;;
        2) cleanup_mysql ;;
        3) cleanup_mongodb ;;
        4) cleanup_redis ;;
        5) return ;;
        *) print_error "Invalid choice."; return ;;
    esac
}

# Called by full cleanup to remove all databases without submenu
cleanup_database_all() {
    cleanup_postgresql
    cleanup_mysql
    cleanup_mongodb
    cleanup_redis
}

cleanup_postgresql() {
    if ! command -v psql &>/dev/null && ! systemctl list-units --type=service 2>/dev/null | grep -q postgresql; then
        return
    fi

    print_warn "Removing PostgreSQL will destroy all databases unless you have backups!"
    if ! confirm "  Remove PostgreSQL?"; then
        return
    fi

    print_step "Removing PostgreSQL..."
    sudo systemctl stop postgresql 2>/dev/null || true
    sudo systemctl disable postgresql 2>/dev/null || true

    if [[ "$PKG" == "apt" ]]; then
        sudo apt-get purge -y postgresql postgresql-contrib 'postgresql-*' 2>/dev/null || true
    else
        sudo yum remove -y postgresql-server postgresql 2>/dev/null || true
    fi

    if confirm "  ${RED}Remove PostgreSQL data directory (/var/lib/postgresql)?${NC}"; then
        sudo rm -rf /var/lib/postgresql
        print_success "PostgreSQL data removed."
    fi

    print_success "PostgreSQL removed."
}

cleanup_mysql() {
    if ! command -v mysql &>/dev/null && ! systemctl list-units --type=service 2>/dev/null | grep -qE 'mysql|mariadb'; then
        return
    fi

    print_warn "Removing MySQL/MariaDB will destroy all databases unless you have backups!"
    if ! confirm "  Remove MySQL/MariaDB?"; then
        return
    fi

    print_step "Removing MySQL/MariaDB..."
    sudo systemctl stop mysql 2>/dev/null || true
    sudo systemctl stop mariadb 2>/dev/null || true
    sudo systemctl disable mysql 2>/dev/null || true
    sudo systemctl disable mariadb 2>/dev/null || true

    if [[ "$PKG" == "apt" ]]; then
        sudo apt-get purge -y mysql-server mysql-client mysql-common 2>/dev/null || true
    else
        sudo yum remove -y mariadb-server mariadb 2>/dev/null || true
    fi

    if confirm "  ${RED}Remove MySQL data directory (/var/lib/mysql)?${NC}"; then
        sudo rm -rf /var/lib/mysql
        print_success "MySQL data removed."
    fi

    print_success "MySQL/MariaDB removed."
}

cleanup_mongodb() {
    if ! command -v mongod &>/dev/null && ! systemctl list-units --type=service 2>/dev/null | grep -q mongod; then
        return
    fi

    print_warn "Removing MongoDB will destroy all databases unless you have backups!"
    if ! confirm "  Remove MongoDB?"; then
        return
    fi

    print_step "Removing MongoDB..."
    sudo systemctl stop mongod 2>/dev/null || true
    sudo systemctl disable mongod 2>/dev/null || true

    if [[ "$PKG" == "apt" ]]; then
        sudo apt-get purge -y mongodb-org* 2>/dev/null || true
        sudo rm -f /etc/apt/sources.list.d/mongodb-org-*.list 2>/dev/null || true
    else
        sudo yum remove -y mongodb-org* 2>/dev/null || true
        sudo rm -f /etc/yum.repos.d/mongodb-org-*.repo 2>/dev/null || true
    fi

    if confirm "  ${RED}Remove MongoDB data directory (/var/lib/mongodb)?${NC}"; then
        sudo rm -rf /var/lib/mongodb
        print_success "MongoDB data removed."
    fi

    print_success "MongoDB removed."
}

cleanup_redis() {
    if ! command -v redis-cli &>/dev/null && ! systemctl list-units --type=service 2>/dev/null | grep -q redis; then
        return
    fi

    if ! confirm "  Remove Redis?"; then
        return
    fi

    print_step "Removing Redis..."
    sudo systemctl stop redis-server 2>/dev/null || true
    sudo systemctl stop redis 2>/dev/null || true
    sudo systemctl disable redis-server 2>/dev/null || true
    sudo systemctl disable redis 2>/dev/null || true

    if [[ "$PKG" == "apt" ]]; then
        sudo apt-get purge -y redis-server 2>/dev/null || true
    else
        sudo yum remove -y redis 2>/dev/null || true
    fi

    print_success "Redis removed."
}

# --- Monitoring ---
cleanup_monitoring() {
    if ! confirm "  Remove monitoring tools (Netdata, Grafana, Node Exporter)?"; then
        return
    fi

    print_step "Removing monitoring tools..."

    # Netdata
    if systemctl list-units --type=service 2>/dev/null | grep -q netdata; then
        sudo systemctl stop netdata 2>/dev/null || true
        sudo systemctl disable netdata 2>/dev/null || true
        if [[ "$PKG" == "apt" ]]; then
            sudo apt-get purge -y netdata 2>/dev/null || true
        else
            sudo yum remove -y netdata 2>/dev/null || true
        fi
        # Netdata kickstart uninstaller
        sudo /usr/libexec/netdata/netdata-uninstaller.sh --yes --force 2>/dev/null || true
        print_success "Netdata removed."
    fi

    # Grafana
    if systemctl list-units --type=service 2>/dev/null | grep -q grafana; then
        sudo systemctl stop grafana-server 2>/dev/null || true
        sudo systemctl disable grafana-server 2>/dev/null || true
        if [[ "$PKG" == "apt" ]]; then
            sudo apt-get purge -y grafana 2>/dev/null || true
            sudo rm -f /etc/apt/sources.list.d/grafana.list 2>/dev/null || true
            sudo rm -f /etc/apt/keyrings/grafana.gpg 2>/dev/null || true
        else
            sudo yum remove -y grafana 2>/dev/null || true
            sudo rm -f /etc/yum.repos.d/grafana.repo 2>/dev/null || true
        fi
        print_success "Grafana removed."
    fi

    # Node Exporter
    if systemctl list-units --type=service 2>/dev/null | grep -q node_exporter; then
        sudo systemctl stop node_exporter 2>/dev/null || true
        sudo systemctl disable node_exporter 2>/dev/null || true
        sudo rm -f /etc/systemd/system/node_exporter.service
        sudo rm -f /usr/local/bin/node_exporter
        sudo systemctl daemon-reload
        sudo userdel node_exporter 2>/dev/null || true
        print_success "Node Exporter removed."
    fi

    print_success "Monitoring tools cleanup complete."
}

# --- Fail2Ban ---
cleanup_fail2ban() {
    if ! confirm "  Remove Fail2Ban?"; then
        return
    fi

    print_step "Removing Fail2Ban..."
    sudo systemctl stop fail2ban 2>/dev/null || true
    sudo systemctl disable fail2ban 2>/dev/null || true

    if [[ "$PKG" == "apt" ]]; then
        sudo apt-get purge -y fail2ban 2>/dev/null || true
    else
        sudo yum remove -y fail2ban 2>/dev/null || true
    fi

    print_success "Fail2Ban removed."
}

# --- Package cache ---
cleanup_cache() {
    print_step "Cleaning package cache..."
    if [[ "$PKG" == "apt" ]]; then
        sudo apt-get clean
    else
        sudo yum clean all
    fi
    print_success "Package cache cleaned."
}

# --- Autoremove ---
cleanup_autoremove() {
    print_step "Removing unused packages..."
    if [[ "$PKG" == "apt" ]]; then
        sudo apt-get autoremove -y
    else
        sudo yum autoremove -y 2>/dev/null || true
    fi
    print_success "Unused packages removed."
}
