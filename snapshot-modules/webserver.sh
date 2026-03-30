#!/bin/bash
# Snapshot Module: Web Server Configurations
# Sourced by snapshot.sh — expects: SNAP_DIR, step(), ok(), warn(), info(), color vars

# ============================================================
#  snap_nginx - Capture Nginx configuration
# ============================================================
snap_nginx() {
    step "Nginx configuration..."

    if ! command -v nginx &>/dev/null; then
        warn "Nginx not found"
        return
    fi

    mkdir -p "$SNAP_DIR/nginx"

    # Main config
    if [ -f "/etc/nginx/nginx.conf" ]; then
        cp /etc/nginx/nginx.conf "$SNAP_DIR/nginx/" 2>/dev/null || true
        info "Copied nginx.conf"
    fi

    # Sites available
    if [ -d "/etc/nginx/sites-available" ]; then
        cp -r /etc/nginx/sites-available "$SNAP_DIR/nginx/" 2>/dev/null || true
        local sa_count
        sa_count=$(ls /etc/nginx/sites-available/ 2>/dev/null | wc -l)
        info "Copied $sa_count sites-available configs"
    fi

    # Sites enabled (list with symlink targets)
    if [ -d "/etc/nginx/sites-enabled" ]; then
        {
            echo "# Sites Enabled (symlink listing)"
            echo "# Captured: $(date)"
            echo ""
            ls -la /etc/nginx/sites-enabled/ 2>/dev/null
        } > "$SNAP_DIR/nginx/sites-enabled-list.txt"
        info "Listed sites-enabled"
    fi

    # conf.d
    if [ -d "/etc/nginx/conf.d" ]; then
        cp -r /etc/nginx/conf.d "$SNAP_DIR/nginx/" 2>/dev/null || true
        local cd_count
        cd_count=$(ls /etc/nginx/conf.d/ 2>/dev/null | wc -l)
        info "Copied $cd_count conf.d configs"
    fi

    # Full config dump (nginx -T resolves all includes)
    nginx -T > "$SNAP_DIR/nginx/full-config-dump.txt" 2>/dev/null || {
        # Try with sudo if direct access fails
        sudo nginx -T > "$SNAP_DIR/nginx/full-config-dump.txt" 2>/dev/null || true
    }

    ok "Nginx configs saved"
}

# ============================================================
#  snap_apache - Capture Apache configuration
# ============================================================
snap_apache() {
    step "Apache configuration..."

    if ! command -v apache2 &>/dev/null && ! command -v httpd &>/dev/null; then
        warn "Apache not found"
        return
    fi

    mkdir -p "$SNAP_DIR/apache"

    # Debian/Ubuntu style (apache2)
    if [ -d "/etc/apache2" ]; then
        # Main config
        if [ -f "/etc/apache2/apache2.conf" ]; then
            cp /etc/apache2/apache2.conf "$SNAP_DIR/apache/" 2>/dev/null || true
            info "Copied apache2.conf"
        fi

        # Sites available
        if [ -d "/etc/apache2/sites-available" ]; then
            cp -r /etc/apache2/sites-available "$SNAP_DIR/apache/" 2>/dev/null || true
            local sa_count
            sa_count=$(ls /etc/apache2/sites-available/ 2>/dev/null | wc -l)
            info "Copied $sa_count sites-available configs"
        fi

        # Sites enabled listing
        if [ -d "/etc/apache2/sites-enabled" ]; then
            {
                echo "# Apache Sites Enabled (symlink listing)"
                echo "# Captured: $(date)"
                echo ""
                ls -la /etc/apache2/sites-enabled/ 2>/dev/null
            } > "$SNAP_DIR/apache/sites-enabled-list.txt"
            info "Listed sites-enabled"
        fi

        # conf.d / conf-available
        if [ -d "/etc/apache2/conf-available" ]; then
            cp -r /etc/apache2/conf-available "$SNAP_DIR/apache/" 2>/dev/null || true
        fi
        if [ -d "/etc/apache2/conf.d" ]; then
            cp -r /etc/apache2/conf.d "$SNAP_DIR/apache/" 2>/dev/null || true
        fi
    fi

    # RHEL/CentOS style (httpd)
    if [ -d "/etc/httpd" ]; then
        # Main config
        if [ -f "/etc/httpd/conf/httpd.conf" ]; then
            cp /etc/httpd/conf/httpd.conf "$SNAP_DIR/apache/" 2>/dev/null || true
            info "Copied httpd.conf"
        fi

        # conf.d
        if [ -d "/etc/httpd/conf.d" ]; then
            cp -r /etc/httpd/conf.d "$SNAP_DIR/apache/" 2>/dev/null || true
            local cd_count
            cd_count=$(ls /etc/httpd/conf.d/ 2>/dev/null | wc -l)
            info "Copied $cd_count conf.d configs"
        fi
    fi

    ok "Apache configs saved"
}

# ============================================================
#  snap_ssl - Capture SSL certificate info and renewal configs
# ============================================================
snap_ssl() {
    step "SSL certificates..."

    {
        echo "# ============================================================"
        echo "#  SSL Certificates"
        echo "#  Captured: $(date)"
        echo "# ============================================================"
        echo ""

        if [ -d "/etc/letsencrypt/live" ]; then
            echo "## Let's Encrypt Certificates"
            echo ""

            local cert_count=0
            for cert_dir in /etc/letsencrypt/live/*/; do
                [ ! -d "$cert_dir" ] && continue
                domain=$(basename "$cert_dir")

                # Skip the README directory that certbot creates
                if [ "$domain" = "README" ]; then
                    continue
                fi

                cert_count=$((cert_count + 1))
                cert_file="$cert_dir/fullchain.pem"

                if [ -f "$cert_file" ]; then
                    expiry=$(openssl x509 -enddate -noout -in "$cert_file" 2>/dev/null | cut -d= -f2)
                    # Also extract the subject/SANs for multi-domain certs
                    sans=$(openssl x509 -text -noout -in "$cert_file" 2>/dev/null | grep -A1 "Subject Alternative Name" | tail -1 | sed 's/DNS://g; s/,/ /g; s/^[[:space:]]*//')

                    echo "  Domain:  $domain"
                    echo "  Expiry:  ${expiry:-unknown}"
                    if [ -n "$sans" ]; then
                        echo "  SANs:    $sans"
                    fi
                    echo ""
                else
                    echo "  Domain:  $domain"
                    echo "  Expiry:  (certificate file not readable)"
                    echo ""
                fi
            done

            if [ "$cert_count" -eq 0 ]; then
                echo "  (no certificate directories found)"
                echo ""
            fi
        else
            echo "  No Let's Encrypt certificates found (/etc/letsencrypt/live does not exist)"
            echo ""
        fi

        # Certbot renewal configs
        echo "## Certbot Renewal Configs"
        echo ""

        if [ -d "/etc/letsencrypt/renewal" ]; then
            local renewal_files
            renewal_files=$(ls /etc/letsencrypt/renewal/*.conf 2>/dev/null)

            if [ -n "$renewal_files" ]; then
                for conf in /etc/letsencrypt/renewal/*.conf; do
                    [ ! -f "$conf" ] && continue
                    conf_name=$(basename "$conf")
                    echo "--- $conf_name ---"
                    cat "$conf" 2>/dev/null || echo "  (could not read)"
                    echo ""
                done
            else
                echo "  (no renewal configs found)"
            fi
        else
            echo "  /etc/letsencrypt/renewal/ does not exist"
        fi

    } > "$SNAP_DIR/ssl.txt"

    # Also copy renewal configs as files for easy restoration
    if [ -d "/etc/letsencrypt/renewal" ]; then
        mkdir -p "$SNAP_DIR/ssl-renewal"
        cp /etc/letsencrypt/renewal/*.conf "$SNAP_DIR/ssl-renewal/" 2>/dev/null || true
    fi

    local cert_summary
    if [ -d "/etc/letsencrypt/live" ]; then
        cert_summary=$(find /etc/letsencrypt/live/ -mindepth 1 -maxdepth 1 -type d ! -name README 2>/dev/null | wc -l)
        ok "SSL info saved ($cert_summary certificates found)"
    else
        ok "SSL info saved (no Let's Encrypt directory)"
    fi
}
