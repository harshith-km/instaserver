#!/bin/bash
# ============================================================
#  System Info Dashboard & Log Viewer
# ============================================================

setup_sysinfo() {
    while true; do
        echo -e "\n${CYAN}── System Info Dashboard ──${NC}"
        echo -e "    1) Show system info summary"
        echo -e "    2) Show running services"
        echo -e "    3) Show open ports"
        echo -e "    4) Show disk usage breakdown"
        echo -e "    5) Show top processes (CPU / Memory)"
        echo -e "    6) Live log viewer"
        echo -e "    0) Back to main menu"
        read -rp "  Choice [0-6]: " sysinfo_choice

        case $sysinfo_choice in
            1) sysinfo_summary ;;
            2) sysinfo_services ;;
            3) sysinfo_ports ;;
            4) sysinfo_disk ;;
            5) sysinfo_processes ;;
            6) sysinfo_logs ;;
            0) return ;;
            *) print_error "Invalid choice." ;;
        esac
    done
}

sysinfo_summary() {
    print_step "Gathering system information..."

    local hostname kernel os_pretty uptime_str load_avg
    local pub_ip priv_ip cpu_model cpu_cores
    local mem_used mem_total mem_pct
    local disk_used disk_total disk_pct
    local swap_used swap_total swap_pct

    hostname=$(hostname)
    kernel=$(uname -r)
    os_pretty=$(grep -i "^PRETTY_NAME" /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')
    os_pretty=${os_pretty:-$(uname -o)}

    uptime_str=$(uptime -p 2>/dev/null || uptime | sed 's/.*up /up /' | sed 's/,.*load.*//')
    load_avg=$(cat /proc/loadavg 2>/dev/null | awk '{print $1", "$2", "$3}')

    pub_ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "unavailable")
    priv_ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    priv_ip=${priv_ip:-$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')}

    cpu_model=$(grep -m1 "model name" /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs)
    cpu_model=${cpu_model:-$(lscpu 2>/dev/null | grep "Model name" | cut -d: -f2 | xargs)}
    cpu_cores=$(nproc 2>/dev/null || grep -c "^processor" /proc/cpuinfo 2>/dev/null || echo "?")

    mem_used=$(free -m | awk '/Mem:/ {print $3}')
    mem_total=$(free -m | awk '/Mem:/ {print $2}')
    if [[ -n "$mem_total" && "$mem_total" -gt 0 ]]; then
        mem_pct=$((mem_used * 100 / mem_total))
    else
        mem_pct="?"
    fi

    disk_used=$(df -h / | awk 'NR==2 {print $3}')
    disk_total=$(df -h / | awk 'NR==2 {print $2}')
    disk_pct=$(df / | awk 'NR==2 {print int($5)}')

    swap_used=$(free -m | awk '/Swap:/ {print $3}')
    swap_total=$(free -m | awk '/Swap:/ {print $2}')
    if [[ -n "$swap_total" && "$swap_total" -gt 0 ]]; then
        swap_pct=$((swap_used * 100 / swap_total))
    else
        swap_pct="N/A"
    fi

    echo -e "\n${CYAN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           ${BOLD}System Info Dashboard${NC}${CYAN}                   ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"

    echo -e ""
    echo -e "  ${BOLD}Hostname:${NC}      $hostname"
    echo -e "  ${BOLD}OS:${NC}            $os_pretty"
    echo -e "  ${BOLD}Kernel:${NC}        $kernel"
    echo -e ""
    echo -e "  ${BOLD}Public IP:${NC}     $pub_ip"
    echo -e "  ${BOLD}Private IP:${NC}    $priv_ip"
    echo -e ""
    echo -e "  ${BOLD}Uptime:${NC}        $uptime_str"
    echo -e "  ${BOLD}Load Average:${NC}  $load_avg"
    echo -e ""
    echo -e "  ${BOLD}CPU:${NC}           $cpu_model"
    echo -e "  ${BOLD}CPU Cores:${NC}     $cpu_cores"
    echo -e ""
    echo -e "  ${BOLD}RAM Usage:${NC}     ${mem_used}MB / ${mem_total}MB (${mem_pct}%)"
    echo -e "  ${BOLD}Disk Usage:${NC}    ${disk_used} / ${disk_total} (${disk_pct}%)"
    echo -e "  ${BOLD}Swap Usage:${NC}    ${swap_used}MB / ${swap_total}MB (${swap_pct}%)"
    echo -e ""

    # Color-coded warnings
    if [[ "$mem_pct" != "?" && "$mem_pct" -ge 85 ]]; then
        print_warn "Memory usage is high (${mem_pct}%)"
    fi
    if [[ "$disk_pct" -ge 80 ]]; then
        print_warn "Disk usage is high (${disk_pct}%)"
    fi

    print_success "System info collected."
}

sysinfo_services() {
    print_step "Checking running services..."

    local services=("nginx" "docker" "pm2" "postgresql" "mysql" "redis" "mongod" "node_exporter" "grafana-server" "netdata" "sshd" "fail2ban" "ufw" "firewalld" "cron" "crond")

    echo -e "\n  ${BOLD}Service                Status${NC}"
    echo -e "  ─────────────────────────────────────"

    for svc in "${services[@]}"; do
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            echo -e "  ${GREEN}●${NC} %-22s ${GREEN}running${NC}" "$svc"
        elif systemctl list-unit-files "${svc}.service" 2>/dev/null | grep -q "$svc"; then
            echo -e "  ${RED}●${NC} %-22s ${RED}stopped${NC}" "$svc"
        fi
    done

    # Check for PM2 separately since it's not always a systemd service
    if command -v pm2 &>/dev/null; then
        local pm2_procs
        pm2_procs=$(pm2 list 2>/dev/null | grep -c "online" || echo "0")
        echo -e "\n  ${BOLD}PM2 processes online:${NC} $pm2_procs"
    fi

    echo -e ""
    if confirm "  Show all running systemd services?"; then
        systemctl list-units --type=service --state=running --no-pager
    fi
}

sysinfo_ports() {
    print_step "Listing open ports..."

    echo -e "\n  ${BOLD}Listening ports (TCP):${NC}\n"

    if command -v ss &>/dev/null; then
        sudo ss -tlnp 2>/dev/null | head -50
    elif command -v netstat &>/dev/null; then
        sudo netstat -tlnp 2>/dev/null | head -50
    else
        print_error "Neither ss nor netstat found. Install net-tools or iproute2."
        return
    fi

    echo -e ""
    if confirm "  Also show UDP listening ports?"; then
        echo -e "\n  ${BOLD}Listening ports (UDP):${NC}\n"
        if command -v ss &>/dev/null; then
            sudo ss -ulnp 2>/dev/null | head -50
        else
            sudo netstat -ulnp 2>/dev/null | head -50
        fi
    fi
}

sysinfo_disk() {
    print_step "Disk usage overview..."

    echo -e "\n  ${BOLD}Filesystem usage:${NC}\n"
    df -h 2>/dev/null

    echo -e "\n  ${BOLD}Largest directories in / (top 10):${NC}\n"
    sudo du -hx --max-depth=1 / 2>/dev/null | sort -rh | head -10

    if command -v ncdu &>/dev/null; then
        if confirm "  Launch ncdu for interactive disk usage browser?"; then
            sudo ncdu /
        fi
    else
        echo -e ""
        if confirm "  Install ncdu for detailed interactive disk breakdown?"; then
            pkg_install ncdu
            sudo ncdu /
        fi
    fi
}

sysinfo_processes() {
    print_step "Top processes..."

    echo -e "\n  Sort by:"
    echo -e "    1) CPU usage"
    echo -e "    2) Memory usage"
    read -rp "  Choice [1-2, default=1]: " proc_choice
    proc_choice=${proc_choice:-1}

    echo -e ""
    case $proc_choice in
        1)
            echo -e "  ${BOLD}Top 15 processes by CPU:${NC}\n"
            ps aux --sort=-%cpu | head -16
            ;;
        2)
            echo -e "  ${BOLD}Top 15 processes by Memory:${NC}\n"
            ps aux --sort=-%mem | head -16
            ;;
        *)
            print_error "Invalid choice."
            return
            ;;
    esac

    echo -e ""
    if confirm "  Launch htop for interactive process viewer?"; then
        if command -v htop &>/dev/null; then
            htop
        else
            print_warn "htop not installed."
            if confirm "  Install htop?"; then
                pkg_install htop
                htop
            fi
        fi
    fi
}

sysinfo_logs() {
    while true; do
        echo -e "\n${CYAN}── Log Viewer ──${NC}"
        echo -e "    1) Nginx access log"
        echo -e "    2) Nginx error log"
        echo -e "    3) System log (syslog/messages)"
        echo -e "    4) PM2 logs"
        echo -e "    5) Docker container logs"
        echo -e "    6) Custom log path"
        echo -e "    0) Back"
        read -rp "  Choice [0-6]: " log_choice

        case $log_choice in
            0) return ;;
            1) _tail_log "/var/log/nginx/access.log" ;;
            2) _tail_log "/var/log/nginx/error.log" ;;
            3)
                if [[ -f /var/log/syslog ]]; then
                    _tail_log "/var/log/syslog"
                elif [[ -f /var/log/messages ]]; then
                    _tail_log "/var/log/messages"
                else
                    print_warn "No syslog or messages file found. Trying journalctl..."
                    read -rp "  Number of lines [default: 50]: " num_lines
                    num_lines=${num_lines:-50}
                    sudo journalctl -n "$num_lines" --no-pager
                    if confirm "  Follow live?"; then
                        print_warn "Press Ctrl+C to stop."
                        sudo journalctl -f
                    fi
                fi
                ;;
            4)
                if command -v pm2 &>/dev/null; then
                    read -rp "  Number of lines [default: 50]: " num_lines
                    num_lines=${num_lines:-50}
                    pm2 logs --lines "$num_lines"
                else
                    print_error "PM2 is not installed."
                fi
                ;;
            5)
                if command -v docker &>/dev/null; then
                    echo -e "\n  ${BOLD}Running containers:${NC}"
                    docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" 2>/dev/null
                    echo -e ""
                    read -rp "  Enter container name or ID: " container_name
                    if [[ -n "$container_name" ]]; then
                        read -rp "  Number of lines [default: 50]: " num_lines
                        num_lines=${num_lines:-50}
                        docker logs --tail "$num_lines" "$container_name" 2>&1
                        if confirm "  Follow live?"; then
                            print_warn "Press Ctrl+C to stop."
                            docker logs -f "$container_name" 2>&1
                        fi
                    fi
                else
                    print_error "Docker is not installed."
                fi
                ;;
            6)
                read -rp "  Enter full log file path: " custom_path
                if [[ -n "$custom_path" ]]; then
                    _tail_log "$custom_path"
                fi
                ;;
            *)
                print_error "Invalid choice."
                ;;
        esac
    done
}

_tail_log() {
    local log_path="$1"

    if [[ ! -f "$log_path" ]]; then
        print_error "Log file not found: $log_path"
        return
    fi

    read -rp "  Number of lines [default: 50]: " num_lines
    num_lines=${num_lines:-50}

    echo -e "\n  ${BOLD}Last $num_lines lines of ${log_path}:${NC}\n"
    sudo tail -n "$num_lines" "$log_path"

    echo -e ""
    if confirm "  Follow live (tail -f)?"; then
        print_warn "Press Ctrl+C to stop."
        sudo tail -f "$log_path"
    fi
}
