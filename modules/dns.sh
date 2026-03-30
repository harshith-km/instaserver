#!/bin/bash
# ============================================================
#  Domain & DNS Utilities
# ============================================================

setup_dns() {
    echo -e "\n${CYAN}── Domain & DNS Utilities ──${NC}"

    echo -e "\n  Select a DNS option:"
    echo -e "    1) Check DNS propagation for a domain"
    echo -e "    2) Verify domain points to this server"
    echo -e "    3) Test HTTP/HTTPS connectivity"
    echo -e "    4) Lookup DNS records (A, AAAA, MX, CNAME, TXT, NS)"
    echo -e "    5) Install and configure dnsutils/bind-utils"
    echo -e "    6) Set up custom hostname"
    echo -e "    7) Back to main menu"
    read -rp "  Choice [1-7]: " dns_choice

    case $dns_choice in
        1) dns_check_propagation ;;
        2) dns_verify_domain ;;
        3) dns_test_connectivity ;;
        4) dns_lookup ;;
        5) dns_install_tools ;;
        6) dns_set_hostname ;;
        7) return ;;
        *) print_error "Invalid choice."; return ;;
    esac
}

# ------------------------------------------------------------------
#  Get this server's public IP
# ------------------------------------------------------------------
_get_public_ip() {
    local ip
    ip=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null) \
        || ip=$(curl -s --max-time 5 https://ifconfig.me 2>/dev/null) \
        || ip=$(curl -s --max-time 5 https://icanhazip.com 2>/dev/null)
    echo "$ip"
}

# ------------------------------------------------------------------
#  1) Check DNS propagation
# ------------------------------------------------------------------
dns_check_propagation() {
    read -rp "  Enter domain name: " domain
    if [[ -z "$domain" ]]; then
        print_warn "No domain provided. Skipping."
        return
    fi

    print_step "Checking DNS propagation for ${BOLD}$domain${NC}..."

    local server_ip
    server_ip=$(_get_public_ip)

    declare -A dns_servers
    dns_servers=(
        ["Google"]="8.8.8.8"
        ["Cloudflare"]="1.1.1.1"
        ["Quad9"]="9.9.9.9"
        ["OpenDNS"]="208.67.222.222"
    )

    local all_match=true

    for name in "${!dns_servers[@]}"; do
        local ns="${dns_servers[$name]}"
        local result

        if command -v dig &>/dev/null; then
            result=$(dig +short A "$domain" @"$ns" 2>/dev/null | head -1)
        else
            result=$(nslookup "$domain" "$ns" 2>/dev/null | awk '/^Address: / { print $2 }' | tail -1)
        fi

        if [[ "$result" == "$server_ip" ]]; then
            echo -e "    ${GREEN}$name ($ns):${NC} $result  ${GREEN}[MATCH]${NC}"
        elif [[ -n "$result" ]]; then
            echo -e "    ${YELLOW}$name ($ns):${NC} $result  ${RED}[MISMATCH]${NC}"
            all_match=false
        else
            echo -e "    ${RED}$name ($ns):${NC} (no result)  ${RED}[FAILED]${NC}"
            all_match=false
        fi
    done

    echo ""
    echo -e "  ${BOLD}Server public IP:${NC} ${server_ip:-unknown}"

    if $all_match && [[ -n "$server_ip" ]]; then
        print_success "All DNS servers resolve $domain to this server."
    else
        print_warn "DNS propagation is incomplete or records do not point here."
    fi
}

# ------------------------------------------------------------------
#  2) Verify domain points to this server
# ------------------------------------------------------------------
dns_verify_domain() {
    read -rp "  Enter domain name: " domain
    if [[ -z "$domain" ]]; then
        print_warn "No domain provided. Skipping."
        return
    fi

    print_step "Verifying $domain points to this server..."

    local server_ip
    server_ip=$(_get_public_ip)

    local resolved_ip
    if command -v dig &>/dev/null; then
        resolved_ip=$(dig +short A "$domain" 2>/dev/null | head -1)
    elif command -v nslookup &>/dev/null; then
        resolved_ip=$(nslookup "$domain" 2>/dev/null | awk '/^Address: / { print $2 }' | tail -1)
    else
        resolved_ip=$(getent hosts "$domain" 2>/dev/null | awk '{ print $1 }')
    fi

    echo -e "  ${BOLD}Domain resolves to:${NC} ${resolved_ip:-unable to resolve}"
    echo -e "  ${BOLD}Server public IP:${NC}  ${server_ip:-unknown}"

    if [[ -n "$resolved_ip" && "$resolved_ip" == "$server_ip" ]]; then
        print_success "Domain $domain points to this server."
        echo -e "  ${GREEN}Ready for SSL setup.${NC}"
    else
        print_error "Domain $domain does NOT point to this server."
        echo -e "  ${YELLOW}Update your DNS A record to point to ${server_ip:-this server's IP}.${NC}"
    fi
}

# ------------------------------------------------------------------
#  3) Test HTTP/HTTPS connectivity
# ------------------------------------------------------------------
dns_test_connectivity() {
    read -rp "  Enter domain name: " domain
    if [[ -z "$domain" ]]; then
        print_warn "No domain provided. Skipping."
        return
    fi

    print_step "Testing HTTP/HTTPS connectivity for $domain..."

    # Test HTTP
    echo -e "\n  ${BOLD}HTTP (port 80):${NC}"
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "http://$domain" 2>/dev/null)
    if [[ -n "$http_code" && "$http_code" != "000" ]]; then
        echo -e "    Response code: ${GREEN}$http_code${NC}"
        local http_redirect
        http_redirect=$(curl -s -o /dev/null -w "%{redirect_url}" --max-time 10 "http://$domain" 2>/dev/null)
        if [[ -n "$http_redirect" ]]; then
            echo -e "    Redirects to:  $http_redirect"
        fi
        # Show full redirect chain
        echo -e "    ${BOLD}Redirect chain:${NC}"
        curl -sIL --max-time 10 "http://$domain" 2>/dev/null | grep -iE "^(HTTP/|Location:)" | sed 's/^/      /'
    else
        print_warn "  HTTP connection failed (port 80 may be closed)."
    fi

    # Test HTTPS
    echo -e "\n  ${BOLD}HTTPS (port 443):${NC}"
    local https_code
    https_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "https://$domain" 2>/dev/null)
    if [[ -n "$https_code" && "$https_code" != "000" ]]; then
        echo -e "    Response code: ${GREEN}$https_code${NC}"
        local https_redirect
        https_redirect=$(curl -s -o /dev/null -w "%{redirect_url}" --max-time 10 "https://$domain" 2>/dev/null)
        if [[ -n "$https_redirect" ]]; then
            echo -e "    Redirects to:  $https_redirect"
        fi
        # Show full redirect chain
        echo -e "    ${BOLD}Redirect chain:${NC}"
        curl -sIL --max-time 10 "https://$domain" 2>/dev/null | grep -iE "^(HTTP/|Location:)" | sed 's/^/      /'
    else
        print_warn "  HTTPS connection failed (port 443 may be closed or no SSL cert)."
    fi
}

# ------------------------------------------------------------------
#  4) DNS record lookup
# ------------------------------------------------------------------
dns_lookup() {
    read -rp "  Enter domain name: " domain
    if [[ -z "$domain" ]]; then
        print_warn "No domain provided. Skipping."
        return
    fi

    print_step "Looking up DNS records for ${BOLD}$domain${NC}..."

    local record_types=("A" "AAAA" "MX" "CNAME" "TXT" "NS")

    for rtype in "${record_types[@]}"; do
        echo -e "\n  ${CYAN}${BOLD}$rtype Records:${NC}"

        local results
        if command -v dig &>/dev/null; then
            results=$(dig +short "$rtype" "$domain" 2>/dev/null)
        elif command -v nslookup &>/dev/null; then
            results=$(nslookup -type="$rtype" "$domain" 2>/dev/null | grep -A999 "^Non-authoritative" | grep -v "^Non-authoritative" | grep -v "^$")
        else
            results="(no dig or nslookup available - install dnsutils first)"
        fi

        if [[ -n "$results" ]]; then
            echo "$results" | sed 's/^/    /'
        else
            echo -e "    ${YELLOW}(no records found)${NC}"
        fi
    done

    echo ""
    print_success "DNS lookup complete."
}

# ------------------------------------------------------------------
#  5) Install DNS tools
# ------------------------------------------------------------------
dns_install_tools() {
    print_step "Installing DNS utilities..."

    if [[ "$PKG" == "apt" ]]; then
        pkg_install dnsutils
    else
        pkg_install bind-utils
    fi

    # Verify installation
    if command -v dig &>/dev/null; then
        print_success "DNS tools installed (dig $(dig -v 2>&1 | head -1))."
    elif command -v nslookup &>/dev/null; then
        print_success "DNS tools installed (nslookup available)."
    else
        print_error "Installation may have failed. Neither dig nor nslookup found."
    fi
}

# ------------------------------------------------------------------
#  6) Set custom hostname
# ------------------------------------------------------------------
dns_set_hostname() {
    local current_hostname
    current_hostname=$(hostname)
    echo -e "  Current hostname: ${BOLD}$current_hostname${NC}"

    read -rp "  Enter new hostname (e.g., server1.example.com): " new_hostname
    if [[ -z "$new_hostname" ]]; then
        print_warn "No hostname provided. Skipping."
        return
    fi

    if ! confirm "  Set hostname to '$new_hostname'?"; then
        print_warn "Cancelled."
        return
    fi

    print_step "Setting hostname to $new_hostname..."
    sudo hostnamectl set-hostname "$new_hostname"

    # Update /etc/hosts
    local short_name="${new_hostname%%.*}"
    if grep -q "127.0.1.1" /etc/hosts 2>/dev/null; then
        sudo sed -i "s/^127\.0\.1\.1.*/127.0.1.1\t$new_hostname\t$short_name/" /etc/hosts
    else
        echo -e "127.0.1.1\t$new_hostname\t$short_name" | sudo tee -a /etc/hosts > /dev/null
    fi

    print_success "Hostname set to $new_hostname."
    echo -e "  ${YELLOW}You may need to open a new shell session for the change to take effect.${NC}"
}
