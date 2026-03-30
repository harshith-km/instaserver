#!/bin/bash
# ============================================================
#  Cron Job Management
# ============================================================

setup_cron() {
    echo -e "\n${CYAN}── Cron Job Management ──${NC}"

    echo -e "\n  ${BOLD}Options:${NC}"
    echo -e "    1) List current cron jobs"
    echo -e "    2) Add a new cron job (interactive)"
    echo -e "    3) Remove a cron job"
    echo -e "    4) Add common presets (cleanup, logs, backup, etc.)"
    echo -e "    5) Back to main menu"
    read -rp "  Choice [1-5]: " cron_choice

    case $cron_choice in
        1) cron_list ;;
        2) cron_add ;;
        3) cron_remove ;;
        4) cron_presets ;;
        5) return ;;
        *) print_error "Invalid choice."; return ;;
    esac
}

cron_list() {
    echo -e "\n${CYAN}── Current Cron Jobs ──${NC}"

    echo -e "\n  ${BOLD}User crontab (${USER}):${NC}"
    local user_crons
    user_crons=$(crontab -l 2>/dev/null)
    if [[ -z "$user_crons" ]]; then
        echo -e "    ${YELLOW}(no cron jobs)${NC}"
    else
        echo "$user_crons" | while IFS= read -r line; do
            echo -e "    $line"
        done
    fi

    echo -e "\n  ${BOLD}Root crontab:${NC}"
    local root_crons
    root_crons=$(sudo crontab -l 2>/dev/null)
    if [[ -z "$root_crons" ]]; then
        echo -e "    ${YELLOW}(no cron jobs)${NC}"
    else
        echo "$root_crons" | while IFS= read -r line; do
            echo -e "    $line"
        done
    fi
    echo ""
}

cron_add() {
    echo -e "\n${CYAN}── Add New Cron Job ──${NC}"

    echo -e "\n  ${BOLD}Select a schedule:${NC}"
    echo -e "    1) Every minute          (* * * * *)"
    echo -e "    2) Every 5 minutes       (*/5 * * * *)"
    echo -e "    3) Every hour            (0 * * * *)"
    echo -e "    4) Daily at midnight     (0 0 * * *)"
    echo -e "    5) Weekly (Sunday)       (0 0 * * 0)"
    echo -e "    6) Monthly (1st)         (0 0 1 * *)"
    echo -e "    7) Custom expression"
    read -rp "  Choice [1-7]: " sched_choice

    local schedule
    case $sched_choice in
        1) schedule="* * * * *" ;;
        2) schedule="*/5 * * * *" ;;
        3) schedule="0 * * * *" ;;
        4) schedule="0 0 * * *" ;;
        5) schedule="0 0 * * 0" ;;
        6) schedule="0 0 1 * *" ;;
        7)
            echo -e "\n  ${BOLD}Cron expression format:${NC}"
            echo -e "    ${BLUE}MIN  HOUR  DAY  MONTH  WEEKDAY${NC}"
            echo -e "    ${BLUE} |     |    |     |       |${NC}"
            echo -e "    ${BLUE} *     *    *     *       *${NC}"
            echo -e ""
            echo -e "  ${BOLD}Hints:${NC}"
            echo -e "    *     = every value         */N   = every N units"
            echo -e "    1,5   = specific values     1-5   = range"
            echo -e "    0-6   = Sun(0) to Sat(6)"
            echo -e ""
            echo -e "  ${BOLD}Examples:${NC}"
            echo -e "    30 2 * * *    = daily at 2:30 AM"
            echo -e "    0 */6 * * *   = every 6 hours"
            echo -e "    0 9 * * 1-5   = weekdays at 9 AM"
            echo -e ""
            read -rp "  Enter cron expression: " schedule
            if [[ -z "$schedule" ]]; then
                print_warn "No expression provided. Aborting."
                return
            fi
            ;;
        *) print_error "Invalid choice."; return ;;
    esac

    read -rp "  Enter the command to run: " cron_cmd
    if [[ -z "$cron_cmd" ]]; then
        print_warn "No command provided. Aborting."
        return
    fi

    local cron_entry="$schedule $cron_cmd"

    echo -e "\n  ${BOLD}Cron entry:${NC} $cron_entry"
    echo -e "\n  Run as:"
    echo -e "    1) Current user ($USER)"
    echo -e "    2) Root"
    read -rp "  Choice [1-2]: " user_choice

    if ! confirm "  Add this cron job?"; then
        print_warn "Cancelled."
        return
    fi

    case $user_choice in
        2)
            print_step "Adding cron job for root..."
            (sudo crontab -l 2>/dev/null; echo "$cron_entry") | sudo crontab -
            ;;
        *)
            print_step "Adding cron job for $USER..."
            (crontab -l 2>/dev/null; echo "$cron_entry") | crontab -
            ;;
    esac

    print_success "Cron job added: $cron_entry"
}

cron_remove() {
    echo -e "\n${CYAN}── Remove Cron Job ──${NC}"

    echo -e "\n  Remove from:"
    echo -e "    1) Current user ($USER)"
    echo -e "    2) Root"
    read -rp "  Choice [1-2]: " user_choice

    local cron_lines
    if [[ "$user_choice" == "2" ]]; then
        cron_lines=$(sudo crontab -l 2>/dev/null | grep -v '^#' | grep -v '^$')
    else
        cron_lines=$(crontab -l 2>/dev/null | grep -v '^#' | grep -v '^$')
    fi

    if [[ -z "$cron_lines" ]]; then
        print_warn "No cron jobs found."
        return
    fi

    echo -e "\n  ${BOLD}Current cron entries:${NC}"
    local i=1
    while IFS= read -r line; do
        echo -e "    ${GREEN}${i})${NC} $line"
        ((i++))
    done <<< "$cron_lines"

    local total=$((i - 1))
    read -rp "  Enter number to remove [1-$total]: " remove_num

    if [[ -z "$remove_num" ]] || [[ "$remove_num" -lt 1 ]] || [[ "$remove_num" -gt "$total" ]]; then
        print_error "Invalid selection."
        return
    fi

    local line_to_remove
    line_to_remove=$(echo "$cron_lines" | sed -n "${remove_num}p")

    echo -e "\n  ${BOLD}Will remove:${NC} $line_to_remove"
    if ! confirm "  Proceed?"; then
        print_warn "Cancelled."
        return
    fi

    if [[ "$user_choice" == "2" ]]; then
        print_step "Removing cron job from root..."
        sudo crontab -l 2>/dev/null | grep -vF "$line_to_remove" | sudo crontab -
    else
        print_step "Removing cron job from $USER..."
        crontab -l 2>/dev/null | grep -vF "$line_to_remove" | crontab -
    fi

    print_success "Cron job removed."
}

cron_presets() {
    echo -e "\n${CYAN}── Common Cron Presets ──${NC}"

    echo -e "\n  ${BOLD}Available presets:${NC}"
    echo -e "    1) Auto-cleanup /tmp (weekly, Sunday 3 AM)"
    echo -e "    2) Auto-cleanup old logs (daily at 4 AM)"
    echo -e "    3) System health check script (every 5 min)"
    echo -e "    4) Database backup (daily at 2 AM)"
    echo -e "    5) SSL certificate renewal check (daily at 6 AM)"
    echo -e "    6) Custom backup script to S3"
    echo -e "    7) Back"
    read -rp "  Choice [1-7]: " preset_choice

    case $preset_choice in
        1) preset_cleanup_tmp ;;
        2) preset_cleanup_logs ;;
        3) preset_health_check ;;
        4) preset_db_backup ;;
        5) preset_ssl_renewal ;;
        6) preset_s3_backup ;;
        7) return ;;
        *) print_error "Invalid choice."; return ;;
    esac
}

preset_cleanup_tmp() {
    echo -e "\n  ${BOLD}Auto-cleanup /tmp${NC}"
    echo -e "  Schedule: Every Sunday at 3:00 AM"
    echo -e "  Action:   Remove files in /tmp older than 7 days"
    echo -e "  Entry:    ${BLUE}0 3 * * 0 find /tmp -type f -mtime +7 -delete 2>/dev/null${NC}"

    if ! confirm "  Add this cron job (root)?"; then
        print_warn "Cancelled."
        return
    fi

    local entry="0 3 * * 0 find /tmp -type f -mtime +7 -delete 2>/dev/null"
    (sudo crontab -l 2>/dev/null | grep -vF "find /tmp -type f -mtime +7 -delete"; echo "$entry") | sudo crontab -
    print_success "Tmp cleanup cron job added."
}

preset_cleanup_logs() {
    echo -e "\n  ${BOLD}Auto-cleanup old logs${NC}"

    read -rp "  Log directory [default: /var/log/app]: " log_dir
    log_dir=${log_dir:-/var/log/app}

    read -rp "  Delete logs older than N days [default: 30]: " log_days
    log_days=${log_days:-30}

    echo -e "\n  Schedule: Daily at 4:00 AM"
    echo -e "  Action:   Remove .log and .gz files in $log_dir older than $log_days days"
    echo -e "  Entry:    ${BLUE}0 4 * * * find $log_dir -type f \\( -name '*.log' -o -name '*.gz' \\) -mtime +$log_days -delete 2>/dev/null${NC}"

    if ! confirm "  Add this cron job (root)?"; then
        print_warn "Cancelled."
        return
    fi

    local entry="0 4 * * * find $log_dir -type f \\( -name '*.log' -o -name '*.gz' \\) -mtime +$log_days -delete 2>/dev/null"
    (sudo crontab -l 2>/dev/null; echo "$entry") | sudo crontab -
    print_success "Log cleanup cron job added for $log_dir."
}

preset_health_check() {
    echo -e "\n  ${BOLD}System Health Check${NC}"
    echo -e "  Schedule: Every 5 minutes"
    echo -e "  Action:   Log CPU, memory, disk usage to /var/log/health-check.log"

    if ! confirm "  Add this cron job (root)?"; then
        print_warn "Cancelled."
        return
    fi

    local script="/usr/local/bin/system-health-check.sh"

    print_step "Creating health check script at $script..."

    sudo tee "$script" > /dev/null <<'HEALTHSCRIPT'
#!/bin/bash
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
LOG="/var/log/health-check.log"

CPU=$(top -bn1 | grep "Cpu(s)" | awk '{printf "%.1f", $2 + $4}')
MEM=$(free | awk '/Mem:/ {printf "%.1f", $3/$2 * 100}')
DISK=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
LOAD=$(cat /proc/loadavg | awk '{print $1, $2, $3}')

echo "[$TIMESTAMP] CPU=${CPU}% MEM=${MEM}% DISK=${DISK}% LOAD=${LOAD}" >> "$LOG"

# Alert if any threshold exceeded
if (( $(echo "$CPU > 90" | bc -l 2>/dev/null || echo 0) )) || \
   (( $(echo "$MEM > 85" | bc -l 2>/dev/null || echo 0) )) || \
   [ "$DISK" -ge 80 ]; then
    echo "[$TIMESTAMP] WARNING: Resource threshold exceeded!" >> "$LOG"
fi
HEALTHSCRIPT

    sudo chmod +x "$script"
    sudo touch /var/log/health-check.log

    local entry="*/5 * * * * $script"
    (sudo crontab -l 2>/dev/null | grep -vF "system-health-check"; echo "$entry") | sudo crontab -
    print_success "Health check cron job added (every 5 min)."
    echo -e "  ${BOLD}Script:${NC} $script"
    echo -e "  ${BOLD}Log:${NC}    /var/log/health-check.log"
}

preset_db_backup() {
    echo -e "\n  ${BOLD}Database Backup${NC}"
    echo -e "  Schedule: Daily at 2:00 AM"

    echo -e "\n  Database type:"
    echo -e "    1) MySQL / MariaDB"
    echo -e "    2) PostgreSQL"
    read -rp "  Choice [1-2]: " db_type

    read -rp "  Database name: " db_name
    if [[ -z "$db_name" ]]; then
        print_warn "No database name provided. Aborting."
        return
    fi

    read -rp "  Backup directory [default: /var/backups/db]: " backup_dir
    backup_dir=${backup_dir:-/var/backups/db}

    read -rp "  Retention days [default: 14]: " retention
    retention=${retention:-14}

    local dump_cmd
    case $db_type in
        1)
            read -rp "  MySQL user [default: root]: " db_user
            db_user=${db_user:-root}
            dump_cmd="mysqldump -u $db_user $db_name"
            echo -e "\n  ${YELLOW}Tip:${NC} Store credentials in ~/.my.cnf for passwordless dumps."
            ;;
        2)
            read -rp "  PostgreSQL user [default: postgres]: " db_user
            db_user=${db_user:-postgres}
            dump_cmd="sudo -u $db_user pg_dump $db_name"
            ;;
        *)
            print_error "Invalid choice."
            return
            ;;
    esac

    local script="/usr/local/bin/db-backup-${db_name}.sh"

    echo -e "\n  ${BOLD}Backup script:${NC} $script"
    echo -e "  ${BOLD}Backup dir:${NC}    $backup_dir"
    echo -e "  ${BOLD}Retention:${NC}     $retention days"

    if ! confirm "  Add this cron job (root)?"; then
        print_warn "Cancelled."
        return
    fi

    print_step "Creating backup script..."

    sudo mkdir -p "$backup_dir"

    sudo tee "$script" > /dev/null <<DBBACKUP
#!/bin/bash
TIMESTAMP=\$(date '+%Y%m%d_%H%M%S')
BACKUP_DIR="$backup_dir"
BACKUP_FILE="\${BACKUP_DIR}/${db_name}_\${TIMESTAMP}.sql.gz"

# Create backup
$dump_cmd | gzip > "\$BACKUP_FILE" 2>/dev/null

if [ \$? -eq 0 ]; then
    echo "[\$(date)] Backup OK: \$BACKUP_FILE" >> /var/log/db-backup.log
else
    echo "[\$(date)] FAILED: $db_name backup" >> /var/log/db-backup.log
fi

# Cleanup old backups
find "\$BACKUP_DIR" -name "${db_name}_*.sql.gz" -mtime +$retention -delete 2>/dev/null
DBBACKUP

    sudo chmod +x "$script"

    local entry="0 2 * * * $script"
    (sudo crontab -l 2>/dev/null | grep -vF "db-backup-${db_name}"; echo "$entry") | sudo crontab -
    print_success "Database backup cron job added for '$db_name' (daily at 2 AM)."
    echo -e "  ${BOLD}Script:${NC} $script"
    echo -e "  ${BOLD}Log:${NC}    /var/log/db-backup.log"
}

preset_ssl_renewal() {
    echo -e "\n  ${BOLD}SSL Certificate Renewal Check${NC}"
    echo -e "  Schedule: Daily at 6:00 AM"
    echo -e "  Action:   Run certbot renew and log results"

    if ! command -v certbot &>/dev/null; then
        print_warn "certbot is not installed. Install it first via the web server module."
        if ! confirm "  Add the cron job anyway?"; then
            return
        fi
    fi

    if ! confirm "  Add this cron job (root)?"; then
        print_warn "Cancelled."
        return
    fi

    local entry="0 6 * * * certbot renew --quiet --post-hook 'systemctl reload nginx 2>/dev/null; systemctl reload apache2 2>/dev/null' >> /var/log/certbot-renew.log 2>&1"

    (sudo crontab -l 2>/dev/null | grep -vF "certbot renew"; echo "$entry") | sudo crontab -
    print_success "SSL renewal check cron job added (daily at 6 AM)."
    echo -e "  ${BOLD}Log:${NC} /var/log/certbot-renew.log"
}

preset_s3_backup() {
    echo -e "\n  ${BOLD}Custom Backup Script to S3${NC}"

    if ! command -v aws &>/dev/null; then
        print_warn "AWS CLI is not installed."
        if confirm "  Install AWS CLI now?"; then
            print_step "Installing AWS CLI..."
            if [[ "$PKG" == "apt" ]]; then
                pkg_install awscli
            else
                pkg_install awscli 2>/dev/null || {
                    curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
                    unzip -qo /tmp/awscliv2.zip -d /tmp
                    sudo /tmp/aws/install 2>/dev/null || sudo /tmp/aws/install --update
                    rm -rf /tmp/aws /tmp/awscliv2.zip
                }
            fi
            print_success "AWS CLI installed."
        else
            if ! confirm "  Continue without AWS CLI?"; then
                return
            fi
        fi
    fi

    read -rp "  S3 bucket name (e.g. my-backups): " s3_bucket
    if [[ -z "$s3_bucket" ]]; then
        print_warn "No bucket name provided. Aborting."
        return
    fi

    read -rp "  Directory to back up [default: /var/www]: " backup_src
    backup_src=${backup_src:-/var/www}

    read -rp "  S3 prefix/path [default: backups]: " s3_prefix
    s3_prefix=${s3_prefix:-backups}

    read -rp "  Schedule - hour (0-23) [default: 3]: " backup_hour
    backup_hour=${backup_hour:-3}

    local script="/usr/local/bin/s3-backup.sh"

    echo -e "\n  ${BOLD}Source:${NC}   $backup_src"
    echo -e "  ${BOLD}Target:${NC}   s3://$s3_bucket/$s3_prefix/"
    echo -e "  ${BOLD}Schedule:${NC} Daily at ${backup_hour}:00"
    echo -e "  ${BOLD}Script:${NC}   $script"

    if ! confirm "  Add this cron job (root)?"; then
        print_warn "Cancelled."
        return
    fi

    print_step "Creating S3 backup script..."

    sudo tee "$script" > /dev/null <<S3BACKUP
#!/bin/bash
TIMESTAMP=\$(date '+%Y%m%d_%H%M%S')
BACKUP_SRC="$backup_src"
S3_DEST="s3://$s3_bucket/$s3_prefix"
LOG="/var/log/s3-backup.log"
ARCHIVE="/tmp/backup_\${TIMESTAMP}.tar.gz"

echo "[\$(date)] Starting backup of \$BACKUP_SRC..." >> "\$LOG"

# Create compressed archive
tar czf "\$ARCHIVE" -C "\$(dirname \$BACKUP_SRC)" "\$(basename \$BACKUP_SRC)" 2>/dev/null

if [ \$? -eq 0 ]; then
    # Upload to S3
    aws s3 cp "\$ARCHIVE" "\$S3_DEST/\$(basename \$ARCHIVE)" >> "\$LOG" 2>&1
    if [ \$? -eq 0 ]; then
        echo "[\$(date)] OK: Uploaded \$ARCHIVE to \$S3_DEST" >> "\$LOG"
    else
        echo "[\$(date)] FAILED: S3 upload failed" >> "\$LOG"
    fi
    rm -f "\$ARCHIVE"
else
    echo "[\$(date)] FAILED: Archive creation failed" >> "\$LOG"
fi

# Cleanup S3 backups older than 30 days
aws s3 ls "\$S3_DEST/" | awk '{print \$4}' | while read -r file; do
    file_date=\$(echo "\$file" | grep -oP '\\d{8}' | head -1)
    if [ -n "\$file_date" ]; then
        cutoff=\$(date -d '30 days ago' '+%Y%m%d' 2>/dev/null || date -v-30d '+%Y%m%d' 2>/dev/null)
        if [ "\$file_date" -lt "\$cutoff" ] 2>/dev/null; then
            aws s3 rm "\$S3_DEST/\$file" >> "\$LOG" 2>&1
        fi
    fi
done
S3BACKUP

    sudo chmod +x "$script"

    local entry="0 $backup_hour * * * $script"
    (sudo crontab -l 2>/dev/null | grep -vF "s3-backup"; echo "$entry") | sudo crontab -
    print_success "S3 backup cron job added (daily at ${backup_hour}:00)."
    echo -e "  ${BOLD}Script:${NC} $script"
    echo -e "  ${BOLD}Log:${NC}    /var/log/s3-backup.log"
    echo -e ""
    echo -e "  ${YELLOW}Note:${NC} Ensure AWS credentials are configured (aws configure)."
}
