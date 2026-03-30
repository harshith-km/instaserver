#!/bin/bash
# Snapshot Module: Database Information
# Sourced by snapshot.sh — expects: SNAP_DIR, step(), ok(), warn(), info(), color variables

snap_databases() {
    step "Database information..."

    {
        echo "# ============================================================"
        echo "#  Database Information"
        echo "#  Captured: $(date)"
        echo "# ============================================================"
        echo ""

        local found=0

        # --- PostgreSQL ---
        if command -v psql &>/dev/null; then
            found=1
            echo "## PostgreSQL"
            echo "  Version: $(psql --version 2>/dev/null)"
            echo "  Status:  $(systemctl is-active postgresql 2>/dev/null || echo 'unknown')"
            echo ""
            echo "  Databases:"
            if sudo -u postgres psql -l 2>/dev/null; then
                :
            else
                echo "    (could not list — check permissions or pg_hba.conf)"
            fi
            echo ""
        fi

        # --- MySQL / MariaDB ---
        if command -v mysql &>/dev/null; then
            found=1
            echo "## MySQL / MariaDB"
            echo "  Version: $(mysql --version 2>/dev/null)"

            local mysql_status
            mysql_status=$(systemctl is-active mysql 2>/dev/null) || \
            mysql_status=$(systemctl is-active mariadb 2>/dev/null) || \
            mysql_status="unknown"
            echo "  Status:  $mysql_status"

            echo ""
            echo "  Databases:"
            if mysql -e "SHOW DATABASES;" 2>/dev/null; then
                :
            else
                echo "    (could not list — check credentials or auth socket)"
            fi
            echo ""
        fi

        # --- MongoDB ---
        if command -v mongosh &>/dev/null || command -v mongo &>/dev/null; then
            found=1
            echo "## MongoDB"
            echo "  Version: $(mongod --version 2>/dev/null | head -1 || echo 'unknown')"
            echo "  Status:  $(systemctl is-active mongod 2>/dev/null || echo 'unknown')"
            echo ""
            echo "  Databases:"
            if command -v mongosh &>/dev/null; then
                mongosh --quiet --eval "db.adminCommand('listDatabases').databases.forEach(d => print('    - ' + d.name))" 2>/dev/null || \
                    echo "    (could not list — auth required?)"
            elif command -v mongo &>/dev/null; then
                mongo --quiet --eval "db.adminCommand('listDatabases').databases.forEach(d => print('    - ' + d.name))" 2>/dev/null || \
                    echo "    (could not list — auth required?)"
            fi
            echo ""
        fi

        # --- Redis ---
        if command -v redis-cli &>/dev/null; then
            found=1
            echo "## Redis"
            echo "  Version: $(redis-server --version 2>/dev/null || echo 'unknown')"

            local redis_status
            redis_status=$(systemctl is-active redis 2>/dev/null) || \
            redis_status=$(systemctl is-active redis-server 2>/dev/null) || \
            redis_status="unknown"
            echo "  Status:  $redis_status"

            local db_size
            db_size=$(redis-cli DBSIZE 2>/dev/null || echo "N/A")
            echo "  DB Size: $db_size"
            echo ""
        fi

        if [ "$found" -eq 0 ]; then
            echo "(No supported databases detected)"
        fi

    } > "$SNAP_DIR/databases.txt"

    ok "Database info saved"
}
