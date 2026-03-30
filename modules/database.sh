#!/bin/bash
# ============================================================
#  Database Setup
# ============================================================

setup_database() {
    echo -e "\n${CYAN}── Database Setup ──${NC}"

    echo -e "\n  Select database to install:"
    echo -e "    1) PostgreSQL"
    echo -e "    2) MySQL / MariaDB"
    echo -e "    3) MongoDB"
    echo -e "    4) Redis"
    echo -e "    5) Multiple (select one by one)"
    echo -e "    6) Back to main menu"
    read -rp "  Choice [1-6]: " db_choice

    case $db_choice in
        1) install_postgresql ;;
        2) install_mysql ;;
        3) install_mongodb ;;
        4) install_redis ;;
        5)
            if confirm "  Install PostgreSQL?"; then install_postgresql; fi
            if confirm "  Install MySQL/MariaDB?"; then install_mysql; fi
            if confirm "  Install MongoDB?"; then install_mongodb; fi
            if confirm "  Install Redis?"; then install_redis; fi
            ;;
        6) return ;;
        *) print_error "Invalid choice."; return ;;
    esac
}

install_postgresql() {
    print_step "Installing PostgreSQL..."
    if [[ "$PKG" == "apt" ]]; then
        pkg_install postgresql postgresql-contrib
    else
        pkg_install postgresql-server postgresql
        sudo postgresql-setup --initdb 2>/dev/null || sudo postgresql-setup initdb
    fi
    sudo systemctl enable postgresql
    sudo systemctl start postgresql
    print_success "PostgreSQL installed and running."
    echo -e "  ${BOLD}Tip:${NC} sudo -u postgres psql  (to access the shell)"
}

install_mysql() {
    print_step "Installing MySQL/MariaDB..."
    if [[ "$PKG" == "apt" ]]; then
        pkg_install mysql-server
        sudo systemctl enable mysql
        sudo systemctl start mysql
    else
        pkg_install mariadb-server mariadb
        sudo systemctl enable mariadb
        sudo systemctl start mariadb
    fi

    if confirm "  Run mysql_secure_installation now?"; then
        sudo mysql_secure_installation
    fi
    print_success "MySQL/MariaDB installed and running."
}

install_mongodb() {
    print_step "Installing MongoDB..."
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
    print_success "MongoDB installed and running."
}

install_redis() {
    print_step "Installing Redis..."
    if [[ "$PKG" == "apt" ]]; then
        pkg_install redis-server
        sudo systemctl enable redis-server
        sudo systemctl start redis-server
    else
        pkg_install redis
        sudo systemctl enable redis
        sudo systemctl start redis
    fi
    print_success "Redis installed and running."
}
