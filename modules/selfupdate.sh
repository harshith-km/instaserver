#!/bin/bash
# ============================================================
#  Self-Update: Check and update instaserver from GitHub
# ============================================================

INSTASERVER_REPO="harshith-km/instaserver"
INSTASERVER_BRANCH="main"
INSTASERVER_RAW_BASE="https://raw.githubusercontent.com/${INSTASERVER_REPO}/${INSTASERVER_BRANCH}"
INSTASERVER_VERSION="${INSTASERVER_VERSION:-0.0.0}"

# ------------------------------------------------------------
#  Version comparison
# ------------------------------------------------------------

_version_gt() {
    # Returns 0 (true) if $1 > $2 using semantic versioning
    local v1="${1#v}"
    local v2="${2#v}"

    local IFS='.'
    local i v1_parts=($v1) v2_parts=($v2)

    for ((i = 0; i < 3; i++)); do
        local a="${v1_parts[i]:-0}"
        local b="${v2_parts[i]:-0}"
        if ((a > b)); then
            return 0
        elif ((a < b)); then
            return 1
        fi
    done
    return 1
}

_fetch_remote_version() {
    local remote_version
    remote_version=$(curl -fsSL --connect-timeout 5 "${INSTASERVER_RAW_BASE}/VERSION" 2>/dev/null)
    if [[ -z "$remote_version" ]]; then
        return 1
    fi
    echo "$remote_version" | tr -d '[:space:]'
}

_get_current_version() {
    # Try VERSION file in script directory first, then the variable
    if [[ -n "$SCRIPT_DIR" ]] && [[ -f "$SCRIPT_DIR/VERSION" ]]; then
        cat "$SCRIPT_DIR/VERSION" | tr -d '[:space:]'
    else
        echo "$INSTASERVER_VERSION"
    fi
}

# ------------------------------------------------------------
#  Check for update (quick, non-interactive)
# ------------------------------------------------------------

check_update() {
    local current_version
    current_version=$(_get_current_version)

    local remote_version
    remote_version=$(_fetch_remote_version 2>/dev/null)

    if [[ -z "$remote_version" ]]; then
        return 1
    fi

    if _version_gt "$remote_version" "$current_version"; then
        echo -e "\n  ${YELLOW}Update available:${NC} ${BOLD}v${current_version}${NC} -> ${GREEN}${BOLD}v${remote_version}${NC}"
        echo -e "  Run the self-update option from the menu to upgrade.\n"
        return 0
    fi
    return 1
}

# ------------------------------------------------------------
#  Self-update (interactive)
# ------------------------------------------------------------

self_update() {
    echo -e "\n${CYAN}── Self-Update ──${NC}"

    local current_version
    current_version=$(_get_current_version)
    echo -e "\n  ${BOLD}Current version:${NC} v${current_version}"

    print_step "Checking for updates..."

    local remote_version
    remote_version=$(_fetch_remote_version)
    if [[ -z "$remote_version" ]]; then
        print_error "Could not reach GitHub to check for updates."
        echo -e "  Check your internet connection and try again."
        return 1
    fi

    echo -e "  ${BOLD}Latest version:${NC}  v${remote_version}"

    if ! _version_gt "$remote_version" "$current_version"; then
        print_success "You are already on the latest version (v${current_version})."
        return 0
    fi

    echo -e "\n  ${GREEN}${BOLD}New version available: v${remote_version}${NC}"

    # Try to fetch and show changelog
    local changelog
    changelog=$(curl -fsSL --connect-timeout 5 "${INSTASERVER_RAW_BASE}/CHANGELOG" 2>/dev/null)
    if [[ -n "$changelog" ]]; then
        echo -e "\n  ${BOLD}What's new:${NC}"
        echo "$changelog" | head -30 | while IFS= read -r line; do
            echo -e "    $line"
        done
        local total_lines
        total_lines=$(echo "$changelog" | wc -l)
        if [[ "$total_lines" -gt 30 ]]; then
            echo -e "    ${YELLOW}... (${total_lines} total lines, showing first 30)${NC}"
        fi
    fi

    echo ""
    if ! confirm "  Update to v${remote_version}?"; then
        print_warn "Update cancelled."
        return 0
    fi

    # Determine target directory
    local target_dir
    if [[ -n "$SCRIPT_DIR" ]] && [[ -d "$SCRIPT_DIR/modules" ]]; then
        target_dir="$SCRIPT_DIR"
    else
        target_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    fi

    print_step "Downloading update to temporary directory..."

    local tmp_dir
    tmp_dir=$(mktemp -d)

    # Download setup.sh
    if ! curl -fsSL "${INSTASERVER_RAW_BASE}/setup.sh" -o "$tmp_dir/setup.sh" 2>/dev/null; then
        print_error "Failed to download setup.sh"
        rm -rf "$tmp_dir"
        return 1
    fi

    # Download VERSION file
    curl -fsSL "${INSTASERVER_RAW_BASE}/VERSION" -o "$tmp_dir/VERSION" 2>/dev/null

    # Download all modules
    mkdir -p "$tmp_dir/modules"

    local modules_list
    modules_list=$(curl -fsSL --connect-timeout 5 "${INSTASERVER_RAW_BASE}/modules/modules.list" 2>/dev/null)

    if [[ -z "$modules_list" ]]; then
        # Fallback: use a known list of modules
        modules_list="common.sh ssh.sh database.sh monitoring.sh webserver.sh hosting.sh git.sh bashrc.sh aws.sh deploy.sh envfile.sh cron.sh multisite.sh backup.sh dns.sh selfupdate.sh export.sh"
    fi

    local failed=0
    for mod in $modules_list; do
        mod=$(echo "$mod" | tr -d '[:space:]')
        [[ -z "$mod" ]] && continue
        echo -e "    Downloading modules/${mod}..."
        if ! curl -fsSL "${INSTASERVER_RAW_BASE}/modules/${mod}" -o "$tmp_dir/modules/${mod}" 2>/dev/null; then
            print_warn "Failed to download modules/${mod} (skipping)"
            ((failed++))
        fi
    done

    if [[ "$failed" -gt 5 ]]; then
        print_error "Too many download failures ($failed). Aborting update."
        rm -rf "$tmp_dir"
        return 1
    fi

    print_step "Replacing files..."

    # Backup current version
    local backup_dir="${target_dir}/.backup-v${current_version}"
    mkdir -p "$backup_dir"
    cp -r "$target_dir/modules" "$backup_dir/" 2>/dev/null
    [[ -f "$target_dir/setup.sh" ]] && cp "$target_dir/setup.sh" "$backup_dir/"
    [[ -f "$target_dir/VERSION" ]] && cp "$target_dir/VERSION" "$backup_dir/"

    # Copy new files into place
    cp "$tmp_dir/setup.sh" "$target_dir/setup.sh"
    [[ -f "$tmp_dir/VERSION" ]] && cp "$tmp_dir/VERSION" "$target_dir/VERSION"
    cp "$tmp_dir/modules/"*.sh "$target_dir/modules/" 2>/dev/null

    # Ensure scripts are executable
    chmod +x "$target_dir/setup.sh"

    # Cleanup
    rm -rf "$tmp_dir"

    print_success "Updated to v${remote_version}"
    echo -e "\n  ${BOLD}Previous version backed up to:${NC} $backup_dir"
    echo -e "  ${YELLOW}Please re-run setup.sh to use the new version.${NC}\n"
}
