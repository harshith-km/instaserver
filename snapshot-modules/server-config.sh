#!/bin/bash
# Snapshot Module: Server Configuration (non-git state)
# Sourced by snapshot.sh — expects: SNAP_DIR, step(), ok(), warn(), info(), color variables

# ============================================================
#  Global Packages (npm, pip3)
# ============================================================
snap_global_packages() {
    step "Global packages (npm, pip3)..."

    {
        echo "# ============================================================"
        echo "#  Globally Installed Packages"
        echo "#  Captured: $(date)"
        echo "# ============================================================"
        echo ""

        # --- npm global packages ---
        if command -v npm &>/dev/null; then
            echo "## npm global packages"
            echo "---"
            npm list -g --depth=0 2>/dev/null || echo "  (could not list npm globals)"
            echo ""
        else
            echo "## npm: not installed"
            echo ""
        fi

        # --- pip3 global packages ---
        if command -v pip3 &>/dev/null; then
            echo "## pip3 packages"
            echo "---"
            pip3 list --format=columns 2>/dev/null || echo "  (could not list pip3 packages)"
            echo ""
        else
            echo "## pip3: not installed"
            echo ""
        fi

    } > "$SNAP_DIR/global-packages.txt"

    ok "Global packages saved to global-packages.txt"
}

# ============================================================
#  Sysctl Configuration
# ============================================================
snap_sysctl() {
    step "Sysctl configuration..."

    mkdir -p "$SNAP_DIR/sysctl"

    local count=0

    # --- Main sysctl.conf ---
    if [ -f /etc/sysctl.conf ]; then
        cp /etc/sysctl.conf "$SNAP_DIR/sysctl/" 2>/dev/null && \
            count=$((count + 1))
        info "Copied /etc/sysctl.conf"
    else
        info "No /etc/sysctl.conf found"
    fi

    # --- Custom sysctl.d/ files ---
    if [ -d /etc/sysctl.d ]; then
        while IFS= read -r f; do
            # Skip README or default files that ship with the OS
            local basename
            basename=$(basename "$f")
            cp "$f" "$SNAP_DIR/sysctl/$basename" 2>/dev/null && \
                count=$((count + 1))
        done < <(find /etc/sysctl.d -maxdepth 1 -type f -name "*.conf" 2>/dev/null)

        if [ "$count" -gt 1 ]; then
            info "Copied $((count - 1)) file(s) from /etc/sysctl.d/"
        fi
    fi

    if [ "$count" -eq 0 ]; then
        warn "No sysctl configuration found"
    else
        ok "Sysctl config saved ($count file(s)) to sysctl/"
    fi
}

# ============================================================
#  Network Configuration
# ============================================================
snap_network() {
    step "Network configuration..."

    {
        echo "# ============================================================"
        echo "#  Network Configuration"
        echo "#  Captured: $(date)"
        echo "# ============================================================"
        echo ""

        # --- /etc/hostname ---
        echo "## /etc/hostname"
        echo "---"
        if [ -f /etc/hostname ]; then
            cat /etc/hostname 2>/dev/null
        else
            echo "  (file not found)"
        fi
        echo ""

        # --- hostname command ---
        echo "## hostname output"
        echo "---"
        hostname 2>/dev/null || echo "  (hostname command failed)"
        echo ""

        # --- /etc/hosts ---
        echo "## /etc/hosts"
        echo "---"
        if [ -f /etc/hosts ]; then
            cat /etc/hosts 2>/dev/null
        else
            echo "  (file not found)"
        fi
        echo ""

        # --- /etc/resolv.conf ---
        echo "## /etc/resolv.conf"
        echo "---"
        if [ -f /etc/resolv.conf ]; then
            cat /etc/resolv.conf 2>/dev/null
        else
            echo "  (file not found)"
        fi
        echo ""

        # --- ip addr ---
        echo "## ip addr"
        echo "---"
        if command -v ip &>/dev/null; then
            ip addr 2>/dev/null || echo "  (ip addr failed)"
        else
            ifconfig 2>/dev/null || echo "  (neither ip nor ifconfig available)"
        fi
        echo ""

    } > "$SNAP_DIR/network.txt"

    ok "Network configuration saved to network.txt"
}

# ============================================================
#  Disk & Mount Information
# ============================================================
snap_disk_mounts() {
    step "Disk and mount information..."

    {
        echo "# ============================================================"
        echo "#  Disk & Mount Information"
        echo "#  Captured: $(date)"
        echo "# ============================================================"
        echo ""

        # --- /etc/fstab ---
        echo "## /etc/fstab"
        echo "---"
        if [ -f /etc/fstab ]; then
            cat /etc/fstab 2>/dev/null
        else
            echo "  (file not found)"
        fi
        echo ""

        # --- lsblk ---
        echo "## lsblk"
        echo "---"
        if command -v lsblk &>/dev/null; then
            lsblk 2>/dev/null || echo "  (lsblk failed)"
        else
            echo "  (lsblk not available)"
        fi
        echo ""

        # --- df -h ---
        echo "## df -h"
        echo "---"
        df -h 2>/dev/null || echo "  (df failed)"
        echo ""

        # --- EBS volumes (if nvme tools available) ---
        if command -v nvme &>/dev/null; then
            echo "## NVMe / EBS Volumes"
            echo "---"
            nvme list 2>/dev/null || echo "  (nvme list failed)"
            echo ""
        fi

        # --- Check for EBS via /dev/xvd* or /dev/nvme* ---
        echo "## Block devices (EBS indicators)"
        echo "---"
        ls -la /dev/xvd* 2>/dev/null || true
        ls -la /dev/nvme* 2>/dev/null || true
        if [ ! -e /dev/xvda ] && [ ! -e /dev/nvme0n1 ]; then
            echo "  (no EBS-style devices detected)"
        fi
        echo ""

    } > "$SNAP_DIR/disk.txt"

    ok "Disk and mount information saved to disk.txt"
}

# ============================================================
#  AWS Instance Metadata
# ============================================================
snap_aws_info() {
    step "AWS instance metadata..."

    local is_ec2=false
    local metadata_base="http://169.254.169.254/latest/meta-data"

    # Quick check: can we reach the metadata endpoint?
    local token
    token=$(curl -s --max-time 2 -X PUT \
        "http://169.254.169.254/latest/api/token" \
        -H "X-aws-ec2-metadata-token-ttl-seconds: 60" 2>/dev/null) || true

    local curl_header=""
    if [ -n "$token" ]; then
        curl_header="-H X-aws-ec2-metadata-token:$token"
        is_ec2=true
    else
        # Try without IMDSv2 token (IMDSv1 fallback)
        if curl -s --max-time 2 "$metadata_base/instance-id" &>/dev/null; then
            is_ec2=true
        fi
    fi

    if [ "$is_ec2" = false ]; then
        warn "Not on EC2 or metadata endpoint unreachable"

        # Still check AWS CLI config
        if command -v aws &>/dev/null; then
            {
                echo "# ============================================================"
                echo "#  AWS CLI Configuration (non-EC2 host)"
                echo "#  Captured: $(date)"
                echo "# ============================================================"
                echo ""
                echo "## aws configure list"
                echo "---"
                aws configure list 2>/dev/null || echo "  (not configured)"
            } > "$SNAP_DIR/aws-instance.txt"
            info "AWS CLI config saved (not on EC2)"
        fi
        return
    fi

    {
        echo "# ============================================================"
        echo "#  AWS EC2 Instance Metadata"
        echo "#  Captured: $(date)"
        echo "# ============================================================"
        echo ""

        _meta() {
            local path="$1"
            if [ -n "$token" ]; then
                curl -s --max-time 3 -H "X-aws-ec2-metadata-token:$token" \
                    "$metadata_base/$path" 2>/dev/null || echo "N/A"
            else
                curl -s --max-time 3 "$metadata_base/$path" 2>/dev/null || echo "N/A"
            fi
        }

        echo "Instance ID:    $(_meta instance-id)"
        echo "Instance Type:  $(_meta instance-type)"
        echo "Region:         $(_meta placement/region 2>/dev/null || _meta placement/availability-zone | sed 's/.$//')"
        echo "Avail. Zone:    $(_meta placement/availability-zone)"
        echo "AMI ID:         $(_meta ami-id)"
        echo "Public IP:      $(_meta public-ipv4)"
        echo "Private IP:     $(_meta local-ipv4)"
        echo "MAC:            $(_meta mac)"
        echo "Security Groups:$(_meta security-groups)"

        echo ""
        echo "## IAM Role"
        echo "---"
        local iam_role
        iam_role=$(_meta iam/info)
        if [ "$iam_role" != "N/A" ] && [ -n "$iam_role" ]; then
            echo "$iam_role"
        else
            echo "  (no IAM role attached)"
        fi

        echo ""
        echo "## AWS CLI Configuration"
        echo "---"
        if command -v aws &>/dev/null; then
            aws configure list 2>/dev/null || echo "  (not configured)"
        else
            echo "  (AWS CLI not installed)"
        fi
        echo ""

    } > "$SNAP_DIR/aws-instance.txt"

    ok "AWS instance metadata saved to aws-instance.txt"
}

# ============================================================
#  Custom Systemd Service Files
# ============================================================
snap_systemd_services() {
    step "Custom systemd service files..."

    mkdir -p "$SNAP_DIR/systemd"

    local count=0

    for svc_dir in /etc/systemd/system /etc/systemd/system/*.wants; do
        [ -d "$svc_dir" ] || continue

        while IFS= read -r f; do
            # Skip symlinks — those are just enabled built-in services
            if [ ! -L "$f" ]; then
                cp "$f" "$SNAP_DIR/systemd/" 2>/dev/null && \
                    count=$((count + 1))
            fi
        done < <(find "$svc_dir" -maxdepth 1 -name "*.service" -type f 2>/dev/null)
    done

    if [ "$count" -eq 0 ]; then
        warn "No custom systemd service files found"
    else
        info "Copied $count custom .service file(s) to systemd/"
        ok "Saved $count custom service file(s)"
    fi
}
