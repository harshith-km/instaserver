#!/bin/bash
# Snapshot Module: Environment files and shell configuration
# Sourced by snapshot.sh - expects SNAP_DIR, step(), ok(), warn(), info()

# ============================================================
#  1. Environment Files (.env)
# ============================================================
snap_env_files() {
    step "Environment files..."

    {
        echo "# ============================================================"
        echo "#  Environment Files"
        echo "#  Captured: $(date)"
        echo "#  NOTE: Only key names are captured - values are NEVER stored"
        echo "# ============================================================"
        echo ""

        local search_dirs=("$HOME" /var/www /opt /srv)
        local total_found=0

        for dir in "${search_dirs[@]}"; do
            [[ -d "$dir" ]] || continue

            echo "## Searching: $dir"
            echo "---"

            local found=0
            while IFS= read -r envfile; do
                [[ -f "$envfile" ]] || continue
                found=1
                total_found=$((total_found + 1))

                local var_count size
                var_count=$(grep -c -E '^[A-Za-z_][A-Za-z0-9_]*=' "$envfile" 2>/dev/null || echo 0)
                size=$(stat --printf='%s' "$envfile" 2>/dev/null || stat -f%z "$envfile" 2>/dev/null || echo "?")

                echo ""
                echo "  File: $envfile"
                echo "  Size: ${size} bytes | Variables: ${var_count}"
                echo "  Key names:"

                # Extract only the key names (left side of =), never the values
                grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$envfile" 2>/dev/null \
                    | sed 's/=.*//' \
                    | sort \
                    | sed 's/^/    /'

            done < <(find "$dir" -maxdepth 4 -name '.env' -o -name '.env.*' 2>/dev/null | sort)

            if [[ $found -eq 0 ]]; then
                echo "  (none found)"
            fi

            echo ""
        done

        echo ""
        echo "## Total .env files found: $total_found"

        echo ""
        echo ""

        # Systemd EnvironmentFile references
        echo "## Systemd EnvironmentFile References"
        echo "---"
        local env_refs
        env_refs=$(grep -r 'EnvironmentFile=' /etc/systemd/system/ /usr/lib/systemd/system/ 2>/dev/null \
            | grep -v '^Binary' \
            | sort -u)

        if [[ -n "$env_refs" ]]; then
            echo "$env_refs" | while IFS= read -r line; do
                echo "  $line"
            done
        else
            echo "  (none found)"
        fi

    } > "$SNAP_DIR/env-files.txt"

    ok "Environment files saved (key names only, no values)"
}

# ============================================================
#  2. Shell Configuration
# ============================================================
snap_shell_config() {
    step "Shell configuration..."

    local shell_dir="$SNAP_DIR/shell-config"
    mkdir -p "$shell_dir"

    local copied=0
    local shell_files=(.bashrc .bash_profile .profile .zshrc)

    {
        echo "# ============================================================"
        echo "#  Shell Configuration"
        echo "#  Captured: $(date)"
        echo "# ============================================================"
        echo ""

        for rc in "${shell_files[@]}"; do
            local src="$HOME/$rc"
            if [[ -f "$src" ]]; then
                cp "$src" "$shell_dir/$rc"
                copied=$((copied + 1))
                local lines
                lines=$(wc -l < "$src")
                echo "  Copied: ~/$rc ($lines lines)"
            else
                echo "  Skipped: ~/$rc (not found)"
            fi
        done

        echo ""
        echo "## Custom Additions to ~/.bashrc"
        echo "---"
        echo "(Lines that appear to be user additions beyond the default system bashrc)"
        echo ""

        if [[ -f "$HOME/.bashrc" ]]; then
            # Heuristic: lines after common end-of-default markers, or lines that
            # don't match typical default patterns. We look for the last occurrence
            # of common default-end markers and capture everything after.
            local bashrc="$HOME/.bashrc"
            local custom_start=0

            # Common markers that signal end of default distro bashrc content
            # Try to find the last default block boundary
            local marker_line
            for marker in \
                "# ~/.bashrc" \
                "# If not running interactively" \
                "# don't put duplicate lines" \
                "# append to the history file" \
                "# enable color support of ls" \
                "# enable programmable completion" \
                "# sources /etc/bash.bashrc" \
                "fi" \
            ; do
                local ln
                ln=$(grep -n "$marker" "$bashrc" 2>/dev/null | tail -1 | cut -d: -f1)
                if [[ -n "$ln" && "$ln" -gt "$custom_start" ]]; then
                    custom_start=$ln
                fi
            done

            if [[ $custom_start -gt 0 ]]; then
                local total_lines
                total_lines=$(wc -l < "$bashrc")
                local after=$((custom_start + 1))
                if [[ $after -le $total_lines ]]; then
                    echo "  (from line $after onward):"
                    echo ""
                    tail -n +"$after" "$bashrc" | grep -v '^[[:space:]]*$' | sed 's/^/    /'
                else
                    echo "  (no custom additions detected)"
                fi
            else
                echo "  (unable to determine default boundary - full file copied)"
            fi
        else
            echo "  (no ~/.bashrc found)"
        fi

    } > "$shell_dir/summary.txt"

    if [[ $copied -gt 0 ]]; then
        ok "Shell configs saved ($copied files copied)"
    else
        warn "No shell config files found"
    fi
}
