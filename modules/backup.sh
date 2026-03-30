#!/bin/bash
# ============================================================
#  Backup Setup (Local + S3)
# ============================================================

setup_backup() {
    echo -e "\n${CYAN}── Backup Setup ──${NC}"

    echo -e "\n  Select backup option:"
    echo -e "    1) Set up database backup (PostgreSQL / MySQL / MongoDB)"
    echo -e "    2) Set up file/directory backup"
    echo -e "    3) Set up backup to S3"
    echo -e "    4) Set up full server snapshot script"
    echo -e "    5) List existing backup cron jobs"
    echo -e "    6) Back to main menu"
    read -rp "  Choice [1-6]: " backup_choice

    case $backup_choice in
        1) backup_database ;;
        2) backup_files ;;
        3) backup_to_s3 ;;
        4) backup_snapshot ;;
        5) list_backup_crons ;;
        6) return ;;
        *) print_error "Invalid choice."; return ;;
    esac
}

# ------------------------------------------------------------
#  Database Backup
# ------------------------------------------------------------

backup_database() {
    echo -e "\n${CYAN}── Database Backup ──${NC}"

    echo -e "\n  Select database type:"
    echo -e "    1) PostgreSQL (pg_dump)"
    echo -e "    2) MySQL (mysqldump)"
    echo -e "    3) MongoDB (mongodump)"
    echo -e "    4) Back"
    read -rp "  Choice [1-4]: " db_type

    case $db_type in
        1) _backup_postgresql ;;
        2) _backup_mysql ;;
        3) _backup_mongodb ;;
        4) return ;;
        *) print_error "Invalid choice."; return ;;
    esac
}

_backup_postgresql() {
    print_step "Setting up PostgreSQL backup..."

    read -rp "  Database name: " db_name
    [[ -z "$db_name" ]] && { print_error "Database name cannot be empty."; return; }
    read -rp "  Database user [postgres]: " db_user
    db_user="${db_user:-postgres}"
    read -rp "  Backup output directory [/var/backups/postgresql]: " out_dir
    out_dir="${out_dir:-/var/backups/postgresql}"
    read -rp "  Retention days (delete backups older than N days) [7]: " retention
    retention="${retention:-7}"

    sudo mkdir -p "$out_dir"

    local script_path="/usr/local/bin/backup-pg-${db_name}.sh"
    sudo tee "$script_path" > /dev/null <<PGEOF
#!/bin/bash
# PostgreSQL backup for: $db_name
TIMESTAMP=\$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$out_dir"
DB_NAME="$db_name"
DB_USER="$db_user"
RETENTION_DAYS=$retention

mkdir -p "\$BACKUP_DIR"

echo "[\$(date)] Starting PostgreSQL backup: \$DB_NAME"
if sudo -u "\$DB_USER" pg_dump "\$DB_NAME" | gzip > "\$BACKUP_DIR/\${DB_NAME}_\${TIMESTAMP}.sql.gz"; then
    echo "[\$(date)] Backup completed: \$BACKUP_DIR/\${DB_NAME}_\${TIMESTAMP}.sql.gz"
else
    echo "[\$(date)] ERROR: pg_dump failed for \$DB_NAME" >&2
    exit 1
fi

# Retention cleanup
find "\$BACKUP_DIR" -name "\${DB_NAME}_*.sql.gz" -mtime +\$RETENTION_DAYS -delete
echo "[\$(date)] Cleaned up backups older than \$RETENTION_DAYS days."
PGEOF
    sudo chmod +x "$script_path"
    print_success "Backup script created: $script_path"

    _offer_cron "$script_path" "PostgreSQL backup ($db_name)"
}

_backup_mysql() {
    print_step "Setting up MySQL backup..."

    read -rp "  Database name: " db_name
    [[ -z "$db_name" ]] && { print_error "Database name cannot be empty."; return; }
    read -rp "  Database user [root]: " db_user
    db_user="${db_user:-root}"
    read -rsp "  Database password: " db_pass
    echo
    read -rp "  Backup output directory [/var/backups/mysql]: " out_dir
    out_dir="${out_dir:-/var/backups/mysql}"
    read -rp "  Retention days [7]: " retention
    retention="${retention:-7}"

    sudo mkdir -p "$out_dir"

    local script_path="/usr/local/bin/backup-mysql-${db_name}.sh"
    sudo tee "$script_path" > /dev/null <<MYEOF
#!/bin/bash
# MySQL backup for: $db_name
TIMESTAMP=\$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$out_dir"
DB_NAME="$db_name"
DB_USER="$db_user"
DB_PASS="$db_pass"
RETENTION_DAYS=$retention

mkdir -p "\$BACKUP_DIR"

echo "[\$(date)] Starting MySQL backup: \$DB_NAME"
if mysqldump -u"\$DB_USER" -p"\$DB_PASS" "\$DB_NAME" | gzip > "\$BACKUP_DIR/\${DB_NAME}_\${TIMESTAMP}.sql.gz"; then
    echo "[\$(date)] Backup completed: \$BACKUP_DIR/\${DB_NAME}_\${TIMESTAMP}.sql.gz"
else
    echo "[\$(date)] ERROR: mysqldump failed for \$DB_NAME" >&2
    exit 1
fi

# Retention cleanup
find "\$BACKUP_DIR" -name "\${DB_NAME}_*.sql.gz" -mtime +\$RETENTION_DAYS -delete
echo "[\$(date)] Cleaned up backups older than \$RETENTION_DAYS days."
MYEOF
    sudo chmod +x "$script_path"
    sudo chmod 700 "$script_path"  # restrict access — contains password
    print_success "Backup script created: $script_path"
    print_warn "Script contains database password — access restricted to root (mode 700)."

    _offer_cron "$script_path" "MySQL backup ($db_name)"
}

_backup_mongodb() {
    print_step "Setting up MongoDB backup..."

    read -rp "  Database name (leave empty for all databases): " db_name
    read -rp "  Backup output directory [/var/backups/mongodb]: " out_dir
    out_dir="${out_dir:-/var/backups/mongodb}"
    read -rp "  Retention days [7]: " retention
    retention="${retention:-7}"

    sudo mkdir -p "$out_dir"

    local db_flag=""
    local label="${db_name:-all}"
    [[ -n "$db_name" ]] && db_flag="--db \"$db_name\""

    local script_path="/usr/local/bin/backup-mongo-${label}.sh"
    sudo tee "$script_path" > /dev/null <<MOEOF
#!/bin/bash
# MongoDB backup for: $label
TIMESTAMP=\$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$out_dir"
RETENTION_DAYS=$retention

mkdir -p "\$BACKUP_DIR"

echo "[\$(date)] Starting MongoDB backup: $label"
if mongodump $db_flag --out "\$BACKUP_DIR/mongodump_\${TIMESTAMP}"; then
    # Compress the dump directory
    tar -czf "\$BACKUP_DIR/mongodump_\${TIMESTAMP}.tar.gz" -C "\$BACKUP_DIR" "mongodump_\${TIMESTAMP}"
    rm -rf "\$BACKUP_DIR/mongodump_\${TIMESTAMP}"
    echo "[\$(date)] Backup completed: \$BACKUP_DIR/mongodump_\${TIMESTAMP}.tar.gz"
else
    echo "[\$(date)] ERROR: mongodump failed for $label" >&2
    exit 1
fi

# Retention cleanup
find "\$BACKUP_DIR" -name "mongodump_*.tar.gz" -mtime +\$RETENTION_DAYS -delete
echo "[\$(date)] Cleaned up backups older than \$RETENTION_DAYS days."
MOEOF
    sudo chmod +x "$script_path"
    print_success "Backup script created: $script_path"

    _offer_cron "$script_path" "MongoDB backup ($label)"
}

# ------------------------------------------------------------
#  File / Directory Backup
# ------------------------------------------------------------

backup_files() {
    echo -e "\n${CYAN}── File/Directory Backup ──${NC}"

    read -rp "  Source directory to back up: " src_dir
    [[ -z "$src_dir" ]] && { print_error "Source directory cannot be empty."; return; }
    [[ ! -d "$src_dir" ]] && { print_error "Directory does not exist: $src_dir"; return; }

    read -rp "  Backup destination directory [/var/backups/files]: " dest_dir
    dest_dir="${dest_dir:-/var/backups/files}"
    read -rp "  Retention days [7]: " retention
    retention="${retention:-7}"

    sudo mkdir -p "$dest_dir"

    # Derive a safe name from the source path
    local safe_name
    safe_name=$(echo "$src_dir" | sed 's|^/||; s|/|_|g')

    local script_path="/usr/local/bin/backup-files-${safe_name}.sh"
    sudo tee "$script_path" > /dev/null <<FILEEOF
#!/bin/bash
# File backup for: $src_dir
TIMESTAMP=\$(date +%Y%m%d_%H%M%S)
SRC_DIR="$src_dir"
BACKUP_DIR="$dest_dir"
RETENTION_DAYS=$retention

mkdir -p "\$BACKUP_DIR"

ARCHIVE_NAME="${safe_name}_\${TIMESTAMP}.tar.gz"

echo "[\$(date)] Starting file backup: \$SRC_DIR"
if tar -czf "\$BACKUP_DIR/\$ARCHIVE_NAME" -C "\$(dirname "\$SRC_DIR")" "\$(basename "\$SRC_DIR")"; then
    echo "[\$(date)] Backup completed: \$BACKUP_DIR/\$ARCHIVE_NAME"
else
    echo "[\$(date)] ERROR: tar failed for \$SRC_DIR" >&2
    exit 1
fi

# Retention cleanup
find "\$BACKUP_DIR" -name "${safe_name}_*.tar.gz" -mtime +\$RETENTION_DAYS -delete
echo "[\$(date)] Cleaned up backups older than \$RETENTION_DAYS days."
FILEEOF
    sudo chmod +x "$script_path"
    print_success "Backup script created: $script_path"

    _offer_cron "$script_path" "File backup ($src_dir)"
}

# ------------------------------------------------------------
#  S3 Backup
# ------------------------------------------------------------

backup_to_s3() {
    echo -e "\n${CYAN}── Backup to S3 ──${NC}"

    # Check for AWS CLI
    if ! command -v aws &>/dev/null; then
        print_warn "AWS CLI is not installed."
        if confirm "  Install AWS CLI now?"; then
            print_step "Installing AWS CLI..."
            if [[ "$PKG" == "apt" ]]; then
                pkg_install unzip curl
            else
                pkg_install unzip curl
            fi
            curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o /tmp/awscliv2.zip
            unzip -qo /tmp/awscliv2.zip -d /tmp
            sudo /tmp/aws/install --update 2>/dev/null || sudo /tmp/aws/install
            rm -rf /tmp/awscliv2.zip /tmp/aws
            if command -v aws &>/dev/null; then
                print_success "AWS CLI installed: $(aws --version)"
            else
                print_error "AWS CLI installation failed."; return
            fi
        else
            print_error "AWS CLI is required for S3 backup."; return
        fi
    fi

    read -rp "  S3 bucket name (e.g. my-backups): " s3_bucket
    [[ -z "$s3_bucket" ]] && { print_error "Bucket name cannot be empty."; return; }
    read -rp "  Local directory to sync: " local_dir
    [[ -z "$local_dir" ]] && { print_error "Local directory cannot be empty."; return; }
    read -rp "  S3 prefix/path (optional, e.g. server1/daily): " s3_prefix

    local s3_target="s3://${s3_bucket}"
    [[ -n "$s3_prefix" ]] && s3_target="${s3_target}/${s3_prefix}"

    echo -e "\n  Sync mode:"
    echo -e "    1) Full sync (aws s3 sync — mirrors local to S3)"
    echo -e "    2) Incremental (aws s3 sync --size-only — only changed files)"
    read -rp "  Choice [1-2]: " sync_mode

    local sync_flags=""
    local mode_label="full"
    case $sync_mode in
        2)
            sync_flags="--size-only"
            mode_label="incremental"
            ;;
    esac

    local safe_name
    safe_name=$(echo "$local_dir" | sed 's|^/||; s|/|_|g')

    local script_path="/usr/local/bin/backup-s3-${safe_name}.sh"
    sudo tee "$script_path" > /dev/null <<S3EOF
#!/bin/bash
# S3 backup ($mode_label sync): $local_dir -> $s3_target
LOCAL_DIR="$local_dir"
S3_TARGET="$s3_target"

echo "[\$(date)] Starting S3 $mode_label sync: \$LOCAL_DIR -> \$S3_TARGET"
if aws s3 sync "\$LOCAL_DIR" "\$S3_TARGET" $sync_flags --delete; then
    echo "[\$(date)] S3 sync completed successfully."
else
    echo "[\$(date)] ERROR: S3 sync failed" >&2
    exit 1
fi
S3EOF
    sudo chmod +x "$script_path"
    print_success "S3 sync script created: $script_path"
    echo -e "  ${BOLD}Mode:${NC} $mode_label  ${BOLD}Target:${NC} $s3_target"

    _offer_cron "$script_path" "S3 backup ($local_dir)"
}

# ------------------------------------------------------------
#  Full Server Snapshot
# ------------------------------------------------------------

backup_snapshot() {
    echo -e "\n${CYAN}── Full Server Snapshot ──${NC}"

    read -rp "  Snapshot output directory [/var/backups/snapshots]: " snap_dir
    snap_dir="${snap_dir:-/var/backups/snapshots}"
    read -rp "  Retention days [7]: " retention
    retention="${retention:-7}"

    local upload_s3="false"
    local s3_target=""
    if confirm "  Upload snapshot to S3 after creation?"; then
        if command -v aws &>/dev/null; then
            read -rp "  S3 bucket (e.g. my-backups): " s3_bucket
            read -rp "  S3 prefix (e.g. snapshots): " s3_prefix
            s3_target="s3://${s3_bucket}"
            [[ -n "$s3_prefix" ]] && s3_target="${s3_target}/${s3_prefix}"
            upload_s3="true"
        else
            print_warn "AWS CLI not installed — skipping S3 upload option."
        fi
    fi

    # Collect additional app directories
    local app_dirs=""
    if confirm "  Include custom application directories?"; then
        read -rp "  App directories (space-separated, e.g. /opt/myapp /srv/webapp): " app_dirs
    fi

    sudo mkdir -p "$snap_dir"

    local script_path="/usr/local/bin/backup-snapshot.sh"
    sudo tee "$script_path" > /dev/null <<'SNAPHEAD'
#!/bin/bash
# Full server snapshot backup
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SNAPHEAD

    sudo tee -a "$script_path" > /dev/null <<SNAPVARS
SNAP_DIR="$snap_dir"
RETENTION_DAYS=$retention
UPLOAD_S3=$upload_s3
S3_TARGET="$s3_target"
APP_DIRS="$app_dirs"
SNAPVARS

    sudo tee -a "$script_path" > /dev/null <<'SNAPBODY'
WORK_DIR=$(mktemp -d /tmp/snapshot_XXXXXXXX)
trap "rm -rf $WORK_DIR" EXIT

mkdir -p "$SNAP_DIR" "$WORK_DIR/databases" "$WORK_DIR/configs" "$WORK_DIR/apps"

echo "[$(date)] Starting full server snapshot..."

# --- Dump databases ---

# PostgreSQL
if command -v pg_dump &>/dev/null && systemctl is-active postgresql &>/dev/null; then
    echo "[$(date)] Dumping PostgreSQL databases..."
    for db in $(sudo -u postgres psql -At -c "SELECT datname FROM pg_database WHERE datistemplate = false AND datname != 'postgres';"); do
        sudo -u postgres pg_dump "$db" | gzip > "$WORK_DIR/databases/pg_${db}.sql.gz" 2>/dev/null && \
            echo "  - PostgreSQL: $db"
    done
fi

# MySQL / MariaDB
if command -v mysqldump &>/dev/null && (systemctl is-active mysql &>/dev/null || systemctl is-active mariadb &>/dev/null); then
    echo "[$(date)] Dumping MySQL/MariaDB databases..."
    for db in $(mysql -N -e "SHOW DATABASES;" 2>/dev/null | grep -Ev '^(information_schema|performance_schema|sys|mysql)$'); do
        mysqldump "$db" 2>/dev/null | gzip > "$WORK_DIR/databases/mysql_${db}.sql.gz" && \
            echo "  - MySQL: $db"
    done
fi

# MongoDB
if command -v mongodump &>/dev/null && systemctl is-active mongod &>/dev/null; then
    echo "[$(date)] Dumping MongoDB databases..."
    mongodump --out "$WORK_DIR/databases/mongodump" &>/dev/null && \
        echo "  - MongoDB: all databases"
fi

# --- Backup configs ---
echo "[$(date)] Backing up configuration files..."

# /etc (selective — avoid huge /etc dirs)
for cfg_dir in /etc/nginx /etc/apache2 /etc/httpd /etc/ssh /etc/systemd /etc/cron.d /etc/logrotate.d /etc/letsencrypt; do
    [[ -d "$cfg_dir" ]] && cp -a "$cfg_dir" "$WORK_DIR/configs/" 2>/dev/null
done

# Copy key config files
for cfg_file in /etc/fstab /etc/hosts /etc/crontab /etc/environment; do
    [[ -f "$cfg_file" ]] && cp -a "$cfg_file" "$WORK_DIR/configs/" 2>/dev/null
done

# Crontabs
if [[ -d /var/spool/cron ]]; then
    cp -a /var/spool/cron "$WORK_DIR/configs/crontabs" 2>/dev/null
fi

# Nginx sites
for sites_dir in /etc/nginx/sites-available /etc/nginx/sites-enabled /etc/nginx/conf.d; do
    [[ -d "$sites_dir" ]] && cp -a "$sites_dir" "$WORK_DIR/configs/" 2>/dev/null
done

# --- Backup app directories ---
if [[ -n "$APP_DIRS" ]]; then
    echo "[$(date)] Backing up application directories..."
    for dir in $APP_DIRS; do
        if [[ -d "$dir" ]]; then
            cp -a "$dir" "$WORK_DIR/apps/" 2>/dev/null && echo "  - $dir"
        fi
    done
fi

# --- Create final archive ---
SNAPSHOT_FILE="$SNAP_DIR/snapshot_${TIMESTAMP}.tar.gz"
echo "[$(date)] Creating snapshot archive..."
if tar -czf "$SNAPSHOT_FILE" -C "$WORK_DIR" .; then
    local_size=$(du -sh "$SNAPSHOT_FILE" | cut -f1)
    echo "[$(date)] Snapshot created: $SNAPSHOT_FILE ($local_size)"
else
    echo "[$(date)] ERROR: Failed to create snapshot archive" >&2
    exit 1
fi

# --- Upload to S3 ---
if [[ "$UPLOAD_S3" == "true" ]] && command -v aws &>/dev/null; then
    echo "[$(date)] Uploading snapshot to $S3_TARGET..."
    if aws s3 cp "$SNAPSHOT_FILE" "$S3_TARGET/snapshot_${TIMESTAMP}.tar.gz"; then
        echo "[$(date)] S3 upload completed."
    else
        echo "[$(date)] WARNING: S3 upload failed" >&2
    fi
fi

# --- Retention cleanup ---
find "$SNAP_DIR" -name "snapshot_*.tar.gz" -mtime +$RETENTION_DAYS -delete
echo "[$(date)] Cleaned up snapshots older than $RETENTION_DAYS days."
echo "[$(date)] Snapshot backup finished."
SNAPBODY

    sudo chmod +x "$script_path"
    print_success "Snapshot script created: $script_path"
    echo -e "  ${BOLD}Output:${NC} $snap_dir"
    [[ "$upload_s3" == "true" ]] && echo -e "  ${BOLD}S3 target:${NC} $s3_target"
    echo -e "  ${BOLD}Tip:${NC} Run manually first to verify:  sudo $script_path"

    _offer_cron "$script_path" "Full server snapshot"
}

# ------------------------------------------------------------
#  List Existing Backup Cron Jobs
# ------------------------------------------------------------

list_backup_crons() {
    echo -e "\n${CYAN}── Existing Backup Cron Jobs ──${NC}\n"

    local found=false

    # Root crontab
    local root_cron
    root_cron=$(sudo crontab -l 2>/dev/null | grep -i "backup" || true)
    if [[ -n "$root_cron" ]]; then
        echo -e "  ${BOLD}Root crontab:${NC}"
        echo "$root_cron" | sed 's/^/    /'
        echo
        found=true
    fi

    # Current user crontab
    local user_cron
    user_cron=$(crontab -l 2>/dev/null | grep -i "backup" || true)
    if [[ -n "$user_cron" ]]; then
        echo -e "  ${BOLD}User ($USER) crontab:${NC}"
        echo "$user_cron" | sed 's/^/    /'
        echo
        found=true
    fi

    # /etc/cron.d
    if ls /etc/cron.d/*backup* &>/dev/null; then
        echo -e "  ${BOLD}/etc/cron.d entries:${NC}"
        for f in /etc/cron.d/*backup*; do
            echo -e "    ${GREEN}$f${NC}"
            cat "$f" | grep -v '^#' | grep -v '^$' | sed 's/^/      /'
        done
        echo
        found=true
    fi

    # Scripts in /usr/local/bin
    local scripts
    scripts=$(ls /usr/local/bin/backup-* 2>/dev/null || true)
    if [[ -n "$scripts" ]]; then
        echo -e "  ${BOLD}Backup scripts in /usr/local/bin:${NC}"
        echo "$scripts" | sed 's/^/    /'
        echo
        found=true
    fi

    if [[ "$found" == "false" ]]; then
        echo -e "  ${YELLOW}No backup cron jobs or scripts found.${NC}"
    fi
}

# ------------------------------------------------------------
#  Helpers
# ------------------------------------------------------------

_offer_cron() {
    local script_path="$1"
    local description="$2"

    if confirm "  Add to cron (daily at 2:00 AM)?"; then
        local log_file="/var/log/$(basename "$script_path" .sh).log"
        local cron_line="0 2 * * * $script_path >> $log_file 2>&1"

        (sudo crontab -l 2>/dev/null; echo "# $description"; echo "$cron_line") | sudo crontab -
        print_success "Cron job added (runs daily at 2:00 AM)."
        echo -e "  ${BOLD}Log:${NC} $log_file"
    else
        echo -e "  ${BOLD}To add manually:${NC}"
        echo -e "    sudo crontab -e"
        echo -e "    0 2 * * * $script_path >> /var/log/$(basename "$script_path" .sh).log 2>&1"
    fi
}
