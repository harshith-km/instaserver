#!/bin/bash
# Snapshot Module: PM2 Processes
# Sourced by snapshot.sh — expects: SNAP_DIR, step(), ok(), warn(), info(), color variables

snap_pm2() {
    step "PM2 processes..."

    if ! command -v pm2 &>/dev/null; then
        warn "PM2 not found"
        return
    fi

    {
        echo "# ============================================================"
        echo "#  PM2 Processes"
        echo "#  Captured: $(date)"
        echo "# ============================================================"
        echo ""

        echo "## Process List"
        echo "---"
        pm2 list 2>/dev/null || echo "  No PM2 processes"

        echo ""
        echo "## Process Details (JSON)"
        echo "---"
        pm2 jlist 2>/dev/null || echo "  (could not retrieve JSON list)"

    } > "$SNAP_DIR/pm2.txt"

    info "PM2 process list written to pm2.txt"

    # --- Save PM2 dump ---
    pm2 save 2>/dev/null || true

    if [ -f "$HOME/.pm2/dump.pm2" ]; then
        cp "$HOME/.pm2/dump.pm2" "$SNAP_DIR/pm2-dump.json" 2>/dev/null || true
        info "PM2 dump copied to pm2-dump.json"
    else
        info "No PM2 dump file found at ~/.pm2/dump.pm2"
    fi

    ok "PM2 process list saved"
}
