#!/bin/bash
# ============================================================
#  Backend, Frontend & Full Stack Hosting Setup
# ============================================================

setup_backend() {
    echo -e "\n${CYAN}── Backend Setup ──${NC}"

    echo -e "\n  Select backend runtime:"
    echo -e "    1) Node.js (Express / Fastify / NestJS etc.)"
    echo -e "    2) Python (Flask / FastAPI / Django etc.)"
    echo -e "    3) Docker (containerized app)"
    read -rp "  Choice [1-3]: " backend_runtime

    case $backend_runtime in
        1)
            install_node
            install_pm2
            ;;
        2)
            install_python
            ;;
        3)
            install_docker
            ;;
        *)
            print_error "Invalid choice."
            return
            ;;
    esac

    # Reverse proxy
    if confirm "  Set up Nginx as reverse proxy?"; then
        install_nginx

        read -rp "  Enter your app's port [default: 3000]: " app_port
        app_port=${app_port:-3000}

        read -rp "  Enter domain name (leave blank for IP-based access): " app_domain

        configure_nginx_backend "$app_port" "$app_domain"

        # SSL
        if [[ -n "$app_domain" ]]; then
            if confirm "  Set up SSL with Let's Encrypt?"; then
                install_certbot
                setup_ssl "$app_domain"
            fi
        fi
    fi

    # Firewall
    if confirm "  Configure firewall (allow SSH, HTTP, HTTPS)?"; then
        setup_firewall
    fi

    # Open custom port
    if [[ "$backend_runtime" != "3" ]]; then
        if confirm "  Open a custom port in firewall (e.g. for direct API access)?"; then
            read -rp "  Port number: " custom_port
            if [[ -n "$custom_port" ]]; then
                if [[ "$PKG" == "apt" ]]; then
                    sudo ufw allow "$custom_port/tcp"
                else
                    sudo firewall-cmd --permanent --add-port="${custom_port}/tcp" 2>/dev/null || true
                    sudo firewall-cmd --reload 2>/dev/null || true
                fi
                print_success "Port $custom_port opened."
            fi
        fi
    fi

    echo -e "\n${GREEN}── Backend setup complete! ──${NC}"

    if [[ "$backend_runtime" == "1" ]]; then
        echo -e "
  ${BOLD}Quick start:${NC}
    1. Clone/upload your project
    2. cd your-project && npm install
    3. pm2 start app.js --name my-app
    4. pm2 save
"
    elif [[ "$backend_runtime" == "2" ]]; then
        echo -e "
  ${BOLD}Quick start:${NC}
    1. Clone/upload your project
    2. python3 -m venv venv && source venv/bin/activate
    3. pip install -r requirements.txt
    4. Run with gunicorn / uvicorn
"
    elif [[ "$backend_runtime" == "3" ]]; then
        echo -e "
  ${BOLD}Quick start:${NC}
    1. Clone/upload your project
    2. docker compose up -d
"
    fi
}

setup_frontend() {
    echo -e "\n${CYAN}── Frontend Setup ──${NC}"

    echo -e "\n  Select frontend type:"
    echo -e "    1) Static site (React / Vue / Angular build output)"
    echo -e "    2) SSR app (Next.js / Nuxt.js - runs as a server)"
    read -rp "  Choice [1-2]: " frontend_type

    case $frontend_type in
        1)
            install_nginx

            read -rp "  Enter web root directory [default: /var/www/html]: " web_root
            web_root=${web_root:-/var/www/html}

            read -rp "  Enter domain name (leave blank for IP-based access): " fe_domain
            configure_nginx_frontend "$web_root" "$fe_domain"

            if confirm "  Install Node.js (for building the frontend on server)?"; then
                install_node
            fi

            if [[ -n "$fe_domain" ]]; then
                if confirm "  Set up SSL with Let's Encrypt?"; then
                    install_certbot
                    setup_ssl "$fe_domain"
                fi
            fi
            ;;
        2)
            install_node
            install_pm2
            install_nginx

            read -rp "  Enter your SSR app's port [default: 3000]: " ssr_port
            ssr_port=${ssr_port:-3000}

            read -rp "  Enter domain name (leave blank for IP-based access): " ssr_domain
            configure_nginx_backend "$ssr_port" "$ssr_domain"

            if [[ -n "$ssr_domain" ]]; then
                if confirm "  Set up SSL with Let's Encrypt?"; then
                    install_certbot
                    setup_ssl "$ssr_domain"
                fi
            fi
            ;;
        *)
            print_error "Invalid choice."
            return
            ;;
    esac

    if confirm "  Configure firewall (allow SSH, HTTP, HTTPS)?"; then
        setup_firewall
    fi

    echo -e "\n${GREEN}── Frontend setup complete! ──${NC}"

    if [[ "$frontend_type" == "1" ]]; then
        echo -e "
  ${BOLD}Quick start:${NC}
    1. Build your project locally: npm run build
    2. Upload build output to: $web_root
       scp -r ./dist/* user@server:$web_root/
"
    else
        echo -e "
  ${BOLD}Quick start:${NC}
    1. Clone/upload your project
    2. cd your-project && npm install && npm run build
    3. pm2 start npm --name my-app -- start
    4. pm2 save
"
    fi
}

setup_fullstack() {
    echo -e "\n${CYAN}── Full Stack Setup ──${NC}"
    echo -e "  This will set up both backend and frontend.\n"
    setup_backend
    echo ""
    setup_frontend
}
