#!/bin/bash
# Snapshot Module: Docker State
# Sourced by snapshot.sh — expects: SNAP_DIR, step(), ok(), warn(), info(), color variables

snap_docker() {
    step "Docker state..."

    if ! command -v docker &>/dev/null; then
        warn "Docker not found"
        return
    fi

    {
        echo "# ============================================================"
        echo "#  Docker State"
        echo "#  Captured: $(date)"
        echo "# ============================================================"
        echo ""

        echo "## Running Containers"
        echo "---"
        docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || \
            echo "  (none or permission denied)"

        echo ""
        echo "## All Containers"
        echo "---"
        docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" 2>/dev/null || \
            echo "  (none or permission denied)"

        echo ""
        echo "## Images"
        echo "---"
        docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" 2>/dev/null || \
            echo "  (none or permission denied)"

        echo ""
        echo "## Volumes"
        echo "---"
        docker volume ls 2>/dev/null || echo "  (none or permission denied)"

        echo ""
        echo "## Networks"
        echo "---"
        docker network ls 2>/dev/null || echo "  (none or permission denied)"

    } > "$SNAP_DIR/docker.txt"

    info "Docker info written to docker.txt"

    # --- Collect docker-compose files ---
    mkdir -p "$SNAP_DIR/docker-compose"

    local compose_count=0
    local search_dirs=("$HOME" /var/www /opt /srv)

    for search_dir in "${search_dirs[@]}"; do
        [ -d "$search_dir" ] || continue

        while IFS= read -r f; do
            # Create a unique filename by replacing / with __
            local dest_name
            dest_name=$(echo "$f" | sed 's|^/||; s|/|__|g')
            cp "$f" "$SNAP_DIR/docker-compose/$dest_name" 2>/dev/null && \
                compose_count=$((compose_count + 1))
        done < <(find "$search_dir" -maxdepth 4 \
            \( -name "docker-compose.yml" -o -name "docker-compose.yaml" \
               -o -name "compose.yml" -o -name "compose.yaml" \) \
            -type f 2>/dev/null)
    done

    if [ "$compose_count" -gt 0 ]; then
        info "Copied $compose_count compose file(s) to docker-compose/"
    fi

    ok "Docker state saved"
}
