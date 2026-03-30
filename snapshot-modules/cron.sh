#!/bin/bash
# Snapshot Module: Cron jobs, systemd timers, logrotate
# Sourced by snapshot.sh - expects SNAP_DIR, step(), ok(), warn(), info()

# ============================================================
#  1. Cron Jobs
# ============================================================
snap_cron() {
    step "Cron jobs..."

    {
        echo "# ============================================================"
        echo "#  Cron Jobs"
        echo "#  Captured: $(date)"
        echo "# ============================================================"
        echo ""

        # Current user crontab
        echo "## User Crontab ($(whoami))"
        echo "---"
        local user_cron
        user_cron=$(crontab -l 2>/dev/null)
        if [[ -n "$user_cron" ]]; then
            echo "$user_cron" | sed 's/^/  /'
        else
            echo "  (no crontab for $(whoami))"
        fi

        echo ""

        # Root crontab
        echo "## Root Crontab"
        echo "---"
        local root_cron
        root_cron=$(sudo crontab -l 2>/dev/null)
        if [[ -n "$root_cron" ]]; then
            echo "$root_cron" | sed 's/^/  /'
        else
            echo "  (no crontab for root, or no sudo access)"
        fi

        echo ""

        # /etc/cron.d/
        echo "## /etc/cron.d/ Contents"
        echo "---"
        if [[ -d /etc/cron.d ]]; then
            for f in /etc/cron.d/*; do
                [[ -f "$f" ]] || continue
                local fname
                fname=$(basename "$f")
                echo ""
                echo "  --- $fname ---"
                if [[ -r "$f" ]]; then
                    grep -v '^[[:space:]]*#\|^[[:space:]]*$' "$f" 2>/dev/null | sed 's/^/    /'
                else
                    echo "    (not readable)"
                fi
            done
        else
            echo "  /etc/cron.d/ not found"
        fi

        echo ""

        # Cron directories summary
        echo "## Cron Script Directories"
        echo "---"
        for period in hourly daily weekly monthly; do
            local dir="/etc/cron.${period}"
            if [[ -d "$dir" ]]; then
                local count
                count=$(find "$dir" -maxdepth 1 -type f 2>/dev/null | wc -l)
                echo "  /etc/cron.${period}/: $count script(s)"
                if [[ $count -gt 0 ]]; then
                    find "$dir" -maxdepth 1 -type f -printf '    %f\n' 2>/dev/null | sort
                fi
            else
                echo "  /etc/cron.${period}/: (not found)"
            fi
        done

    } > "$SNAP_DIR/cron.txt"

    ok "Cron jobs saved"
}

# ============================================================
#  2. Systemd Timers
# ============================================================
snap_systemd_timers() {
    step "Systemd timers..."

    {
        echo "# ============================================================"
        echo "#  Active Systemd Timers"
        echo "#  Captured: $(date)"
        echo "# ============================================================"
        echo ""

        if command -v systemctl &>/dev/null; then
            systemctl list-timers --all --no-pager 2>/dev/null || echo "Unable to list timers"
        else
            echo "systemctl not available"
        fi

    } > "$SNAP_DIR/timers.txt"

    ok "Systemd timers saved"
}

# ============================================================
#  3. Logrotate Configuration
# ============================================================
snap_logrotate() {
    step "Logrotate configs..."

    local logrotate_src="/etc/logrotate.d"
    local logrotate_dst="$SNAP_DIR/logrotate"

    if [[ ! -d "$logrotate_src" ]]; then
        warn "No /etc/logrotate.d/ directory found"
        return
    fi

    mkdir -p "$logrotate_dst"

    local copied=0
    for f in "$logrotate_src"/*; do
        [[ -f "$f" ]] || continue
        local fname
        fname=$(basename "$f")
        if [[ -r "$f" ]]; then
            cp "$f" "$logrotate_dst/$fname"
            copied=$((copied + 1))
        else
            echo "# Not readable (insufficient permissions)" > "$logrotate_dst/$fname.skipped"
        fi
    done

    if [[ $copied -gt 0 ]]; then
        ok "Logrotate configs saved ($copied files from $logrotate_src)"
    else
        warn "No readable logrotate configs found"
    fi
}
