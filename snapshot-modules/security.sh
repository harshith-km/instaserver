#!/bin/bash
# Snapshot Module: Security - SSH, firewall, users
# Sourced by snapshot.sh - expects SNAP_DIR, step(), ok(), warn(), info()

# ============================================================
#  1. SSH Configuration & Keys
# ============================================================
snap_ssh() {
    step "SSH configuration..."

    {
        echo "# ============================================================"
        echo "#  SSH Configuration"
        echo "#  Captured: $(date)"
        echo "# ============================================================"
        echo ""

        # Key sshd_config settings
        echo "## sshd_config settings"
        echo "---"
        local sshd_conf="/etc/ssh/sshd_config"
        if [[ -f "$sshd_conf" ]]; then
            for setting in Port PermitRootLogin PasswordAuthentication PubkeyAuthentication ClientAliveInterval MaxAuthTries; do
                # Get the effective value: last non-commented match wins
                local val
                val=$(grep -i "^[[:space:]]*${setting}" "$sshd_conf" 2>/dev/null | tail -1 | awk '{print $2}')
                if [[ -n "$val" ]]; then
                    echo "  $setting: $val"
                else
                    echo "  $setting: (default / not set)"
                fi
            done
        else
            echo "  sshd_config not found at $sshd_conf"
        fi

        echo ""

        # Authorized keys
        echo "## Authorized Keys"
        echo "---"
        local auth_keys="$HOME/.ssh/authorized_keys"
        if [[ -f "$auth_keys" ]]; then
            local key_count
            key_count=$(grep -c -v '^[[:space:]]*$\|^#' "$auth_keys" 2>/dev/null || echo 0)
            echo "  Count: $key_count key(s) in $auth_keys"
            echo ""
            echo "  Fingerprints:"
            while IFS= read -r line; do
                [[ -z "$line" || "$line" == \#* ]] && continue
                local fp
                fp=$(echo "$line" | ssh-keygen -lf - 2>/dev/null)
                if [[ -n "$fp" ]]; then
                    echo "    $fp"
                fi
            done < "$auth_keys"
        else
            echo "  No authorized_keys file found"
        fi

        echo ""

        # SSH key files in ~/.ssh/
        echo "## SSH Keys in ~/.ssh/"
        echo "---"
        if [[ -d "$HOME/.ssh" ]]; then
            local found_keys=0
            for keyfile in "$HOME"/.ssh/id_* "$HOME"/.ssh/*.pub; do
                [[ -f "$keyfile" ]] || continue
                found_keys=1
                local fname
                fname=$(basename "$keyfile")
                local fp
                fp=$(ssh-keygen -lf "$keyfile" 2>/dev/null | awk '{print $1, $2, $4}')
                echo "  $fname  ${fp:-unable to read fingerprint}"
            done
            if [[ $found_keys -eq 0 ]]; then
                echo "  No SSH key files found"
            fi
        else
            echo "  ~/.ssh/ directory does not exist"
        fi

    } > "$SNAP_DIR/ssh.txt"

    ok "SSH configuration saved"
}

# ============================================================
#  2. Firewall Rules
# ============================================================
snap_firewall() {
    step "Firewall rules..."

    {
        echo "# ============================================================"
        echo "#  Firewall Rules"
        echo "#  Captured: $(date)"
        echo "# ============================================================"
        echo ""

        # UFW
        echo "## UFW Status"
        echo "---"
        if command -v ufw &>/dev/null; then
            ufw status verbose 2>/dev/null || echo "  Unable to read UFW status (may need root)"
        else
            echo "  ufw not installed"
        fi

        echo ""

        # firewalld
        echo "## Firewalld"
        echo "---"
        if command -v firewall-cmd &>/dev/null; then
            echo "  State: $(firewall-cmd --state 2>/dev/null || echo 'unknown')"
            echo ""
            echo "  Active zones:"
            firewall-cmd --get-active-zones 2>/dev/null || true
            echo ""
            echo "  Rules (default zone):"
            firewall-cmd --list-all 2>/dev/null || echo "  Unable to read firewalld rules"
        else
            echo "  firewalld not installed"
        fi

        echo ""

        # iptables
        echo "## iptables Rules"
        echo "---"
        if command -v iptables &>/dev/null; then
            iptables -L -n --line-numbers 2>/dev/null || echo "  Unable to read iptables (may need root)"
            echo ""
            echo "  NAT table:"
            iptables -t nat -L -n --line-numbers 2>/dev/null || echo "  Unable to read NAT rules"
        else
            echo "  iptables not available"
        fi

    } > "$SNAP_DIR/firewall.txt"

    ok "Firewall rules saved"
}

# ============================================================
#  3. Users & Sudo Access
# ============================================================
snap_users() {
    step "Users and access..."

    {
        echo "# ============================================================"
        echo "#  Users & Sudo Access"
        echo "#  Captured: $(date)"
        echo "# ============================================================"
        echo ""

        echo "## Non-System Users (UID >= 1000)"
        echo "---"
        echo ""
        printf "%-20s %-6s %-25s %-20s %s\n" "USERNAME" "UID" "HOME" "SHELL" "GROUPS"
        printf "%-20s %-6s %-25s %-20s %s\n" "--------" "---" "----" "-----" "------"

        while IFS=: read -r username _pass uid _gid _gecos homedir shell; do
            # Skip nfsnobody (UID 65534) and other well-known non-login UIDs
            [[ "$uid" -lt 1000 ]] 2>/dev/null && continue
            [[ "$username" == "nobody" || "$username" == "nfsnobody" ]] && continue

            local groups
            groups=$(groups "$username" 2>/dev/null | sed "s/^${username} : //" || echo "N/A")
            printf "%-20s %-6s %-25s %-20s %s\n" "$username" "$uid" "$homedir" "$shell" "$groups"
        done < /etc/passwd

        echo ""

        # Sudo access
        echo "## Sudo Access"
        echo "---"
        echo ""

        # Check /etc/sudoers
        if [[ -r /etc/sudoers ]]; then
            echo "  /etc/sudoers (non-comment rules):"
            grep -v '^[[:space:]]*#\|^[[:space:]]*$\|^Defaults' /etc/sudoers 2>/dev/null | sed 's/^/    /'
        else
            echo "  /etc/sudoers: not readable (need root)"
        fi

        echo ""

        # Check /etc/sudoers.d/
        if [[ -d /etc/sudoers.d ]]; then
            echo "  /etc/sudoers.d/ files:"
            for f in /etc/sudoers.d/*; do
                [[ -f "$f" ]] || continue
                local fname
                fname=$(basename "$f")
                echo "    --- $fname ---"
                if [[ -r "$f" ]]; then
                    grep -v '^[[:space:]]*#\|^[[:space:]]*$' "$f" 2>/dev/null | sed 's/^/      /'
                else
                    echo "      (not readable)"
                fi
            done
        else
            echo "  /etc/sudoers.d/: not found"
        fi

        echo ""

        # Members of sudo/wheel group
        echo "## Users in sudo/wheel groups"
        echo "---"
        for grp in sudo wheel; do
            local members
            members=$(getent group "$grp" 2>/dev/null | cut -d: -f4)
            if [[ -n "$members" ]]; then
                echo "  $grp: $members"
            fi
        done

    } > "$SNAP_DIR/users.txt"

    ok "Users and access saved"
}
