#!/bin/bash
# Snapshot Module: Projects & Directory Trees
# Sourced by snapshot.sh — expects: SNAP_DIR, step(), ok(), warn(), info(), color vars

# ============================================================
#  snap_projects - Scan for git repositories and project info
# ============================================================
snap_projects() {
    step "Scanning project directories..."

    SCAN_DIRS=("$HOME" "/var/www" "/opt" "/srv")

    {
        echo "# ============================================================"
        echo "#  Project Directories & Git Repositories"
        echo "#  Scanned: ${SCAN_DIRS[*]}"
        echo "#  Captured: $(date)"
        echo "# ============================================================"
        echo ""

        for scan_dir in "${SCAN_DIRS[@]}"; do
            if [ ! -d "$scan_dir" ]; then
                continue
            fi

            echo "## $scan_dir"
            echo "---"

            # Find git repos (max depth 4)
            while IFS= read -r git_dir; do
                repo_dir=$(dirname "$git_dir")
                rel_path="${repo_dir#$scan_dir/}"

                echo ""
                echo "### $rel_path"
                echo "  Path:   $repo_dir"

                # Git remote, branch, last commit
                if [ -d "$git_dir" ]; then
                    remote=$(git -C "$repo_dir" remote get-url origin 2>/dev/null || echo "no remote")
                    branch=$(git -C "$repo_dir" branch --show-current 2>/dev/null || echo "unknown")
                    last_commit=$(git -C "$repo_dir" log -1 --format="%h %s (%cr)" 2>/dev/null || echo "unknown")
                    echo "  Remote: $remote"
                    echo "  Branch: $branch"
                    echo "  Last:   $last_commit"
                fi

                # --- Detect project type ---
                project_type=""
                framework=""

                if [ -f "$repo_dir/package.json" ]; then
                    pkg_name=$(grep -o '"name":[^,]*' "$repo_dir/package.json" 2>/dev/null | head -1 | cut -d'"' -f4)
                    project_type="Node.js ($pkg_name)"

                    # Detect framework from package.json and config files
                    if [ -f "$repo_dir/next.config.js" ] || [ -f "$repo_dir/next.config.mjs" ] || [ -f "$repo_dir/next.config.ts" ]; then
                        framework="Next.js"
                    elif grep -q '"nuxt"' "$repo_dir/package.json" 2>/dev/null; then
                        framework="Nuxt"
                    elif grep -q '"react"' "$repo_dir/package.json" 2>/dev/null; then
                        # Check for React before Vue since some projects have both
                        framework="React"
                    elif grep -q '"vue"' "$repo_dir/package.json" 2>/dev/null; then
                        framework="Vue"
                    fi

                    # Backend framework detection (can coexist with frontend)
                    backend_fw=""
                    if grep -q '"express"' "$repo_dir/package.json" 2>/dev/null; then
                        backend_fw="Express"
                    elif grep -q '"fastify"' "$repo_dir/package.json" 2>/dev/null; then
                        backend_fw="Fastify"
                    elif grep -q '"@nestjs/core"' "$repo_dir/package.json" 2>/dev/null; then
                        backend_fw="NestJS"
                    fi

                    if [ -n "$backend_fw" ]; then
                        if [ -n "$framework" ]; then
                            framework="$framework + $backend_fw"
                        else
                            framework="$backend_fw"
                        fi
                    fi

                elif [ -f "$repo_dir/requirements.txt" ]; then
                    project_type="Python"
                    if [ -f "$repo_dir/manage.py" ]; then
                        framework="Django"
                    elif grep -qi "fastapi" "$repo_dir/requirements.txt" 2>/dev/null; then
                        framework="FastAPI"
                    elif grep -qi "flask" "$repo_dir/requirements.txt" 2>/dev/null; then
                        framework="Flask"
                    fi

                elif [ -f "$repo_dir/go.mod" ]; then
                    project_type="Go"

                elif [ -f "$repo_dir/Cargo.toml" ]; then
                    project_type="Rust"

                elif [ -f "$repo_dir/Gemfile" ]; then
                    project_type="Ruby"

                elif [ -f "$repo_dir/pom.xml" ] || [ -f "$repo_dir/build.gradle" ]; then
                    project_type="Java"

                elif [ -f "$repo_dir/Dockerfile" ] || [ -f "$repo_dir/docker-compose.yml" ] || [ -f "$repo_dir/compose.yml" ]; then
                    project_type="Docker"
                fi

                if [ -n "$project_type" ]; then
                    echo "  Type:   $project_type"
                fi
                if [ -n "$framework" ]; then
                    echo "  Framework: $framework"
                fi

            done < <(find "$scan_dir" -maxdepth 4 -name ".git" -type d 2>/dev/null)

            echo ""
        done

        # List all directories in /var/www with sizes
        if [ -d "/var/www" ]; then
            echo ""
            echo "## /var/www (all directories with sizes)"
            echo "---"
            for dir in /var/www/*/; do
                if [ -d "$dir" ]; then
                    size=$(du -sh "$dir" 2>/dev/null | cut -f1)
                    echo "  $dir ($size)"
                fi
            done
        fi

    } > "$SNAP_DIR/projects.txt"

    repo_count=$(grep -c "^### " "$SNAP_DIR/projects.txt" 2>/dev/null || echo "0")
    ok "Found $repo_count git repositories"
}

# ============================================================
#  snap_directory_tree - Save directory trees of key paths
# ============================================================
snap_directory_tree() {
    step "Directory structure..."

    {
        echo "# ============================================================"
        echo "#  Directory Trees (depth 2)"
        echo "#  Captured: $(date)"
        echo "# ============================================================"

        for dir in "$HOME" "/var/www" "/opt" "/srv"; do
            if [ ! -d "$dir" ]; then
                continue
            fi

            echo ""
            echo "## $dir"
            echo "---"

            if command -v tree &>/dev/null; then
                tree -L 2 -d --noreport "$dir" 2>/dev/null || echo "  (could not read)"
            else
                # Fallback: use find to mimic directory-only tree
                find "$dir" -maxdepth 2 -type d 2>/dev/null | while IFS= read -r d; do
                    # Calculate depth relative to base dir for indentation
                    rel="${d#$dir}"
                    rel="${rel#/}"
                    if [ -z "$rel" ]; then
                        echo "$dir"
                    else
                        depth=$(echo "$rel" | tr -cd '/' | wc -c)
                        indent=""
                        for ((i = 0; i < depth; i++)); do
                            indent="$indent    "
                        done
                        basename_d=$(basename "$d")
                        echo "${indent}    ${basename_d}/"
                    fi
                done
            fi
        done

    } > "$SNAP_DIR/directory-tree.txt"

    ok "Directory trees saved"
}
