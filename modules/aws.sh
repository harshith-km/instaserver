#!/bin/bash
# ============================================================
#  AWS CLI Setup & Configuration
# ============================================================

setup_aws() {
    echo -e "\n${CYAN}── AWS CLI Setup & Configuration ──${NC}"

    echo -e "\n  Select an option:"
    echo -e "    1) Install AWS CLI v2"
    echo -e "    2) Configure AWS credentials"
    echo -e "    3) Set up named profiles"
    echo -e "    4) Install SSM Session Manager plugin"
    echo -e "    5) Configure S3 bucket access"
    echo -e "    6) Install CloudFormation helper scripts"
    echo -e "    7) All of the above"
    echo -e "    8) Back to main menu"
    read -rp "  Choice [1-8]: " aws_choice

    case $aws_choice in
        1) install_aws_cli ;;
        2) configure_aws ;;
        3) setup_aws_profile ;;
        4) install_ssm_plugin ;;
        5) configure_s3_access ;;
        6) install_cfn_helpers ;;
        7)
            install_aws_cli
            configure_aws
            setup_aws_profile
            install_ssm_plugin
            configure_s3_access
            install_cfn_helpers
            ;;
        8) return ;;
        *) print_error "Invalid choice."; return ;;
    esac
}

install_aws_cli() {
    print_step "Installing AWS CLI v2..."

    if command -v aws &>/dev/null; then
        local current_version
        current_version=$(aws --version 2>&1 | awk '{print $1}' | cut -d/ -f2)
        print_warn "AWS CLI already installed (v${current_version})."
        if ! confirm "  Reinstall / upgrade?"; then
            return
        fi
    fi

    local arch
    arch=$(uname -m)
    local cli_url

    case "$arch" in
        x86_64)
            cli_url="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
            ;;
        aarch64)
            cli_url="https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip"
            ;;
        *)
            print_error "Unsupported architecture: $arch"
            return 1
            ;;
    esac

    print_step "Downloading AWS CLI v2 for ${arch}..."
    local tmpdir
    tmpdir=$(mktemp -d)
    curl -fsSL "$cli_url" -o "${tmpdir}/awscliv2.zip"
    unzip -qo "${tmpdir}/awscliv2.zip" -d "${tmpdir}"

    if command -v aws &>/dev/null; then
        sudo "${tmpdir}/aws/install" --update
    else
        sudo "${tmpdir}/aws/install"
    fi

    rm -rf "${tmpdir}"

    if command -v aws &>/dev/null; then
        print_success "AWS CLI v2 installed ($(aws --version 2>&1 | awk '{print $1}'))."
    else
        print_error "AWS CLI installation failed."
        return 1
    fi
}

configure_aws() {
    print_step "Configuring AWS credentials..."

    if ! command -v aws &>/dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        return 1
    fi

    echo -e "  ${BOLD}This will configure the default AWS profile.${NC}"
    echo -e "  You will be prompted for:"
    echo -e "    - AWS Access Key ID"
    echo -e "    - AWS Secret Access Key"
    echo -e "    - Default region (e.g., us-east-1, ap-south-1)"
    echo -e "    - Output format (json, text, table)"
    echo ""

    aws configure

    if aws sts get-caller-identity &>/dev/null; then
        local account_id
        account_id=$(aws sts get-caller-identity --query "Account" --output text)
        print_success "AWS credentials configured. Account ID: ${account_id}"
    else
        print_warn "Credentials saved, but could not verify. Check your access key and secret."
    fi
}

setup_aws_profile() {
    print_step "Setting up a named AWS profile..."

    if ! command -v aws &>/dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        return 1
    fi

    read -rp "  Enter profile name (e.g., dev, staging, production): " profile_name
    if [[ -z "$profile_name" ]]; then
        print_error "Profile name cannot be empty."
        return 1
    fi

    echo -e "  ${BOLD}Configuring profile: ${GREEN}${profile_name}${NC}"
    aws configure --profile "$profile_name"

    if aws sts get-caller-identity --profile "$profile_name" &>/dev/null; then
        local account_id
        account_id=$(aws sts get-caller-identity --profile "$profile_name" --query "Account" --output text)
        print_success "Profile '${profile_name}' configured. Account ID: ${account_id}"
    else
        print_warn "Profile '${profile_name}' saved, but could not verify credentials."
    fi

    echo -e "  ${BOLD}Tip:${NC} Use ${CYAN}export AWS_PROFILE=${profile_name}${NC} or pass ${CYAN}--profile ${profile_name}${NC} to commands."
}

install_ssm_plugin() {
    print_step "Installing SSM Session Manager plugin..."

    if command -v session-manager-plugin &>/dev/null; then
        print_warn "SSM Session Manager plugin is already installed."
        if ! confirm "  Reinstall?"; then
            return
        fi
    fi

    local arch
    arch=$(uname -m)

    if [[ "$PKG" == "apt" ]]; then
        local deb_url
        if [[ "$arch" == "aarch64" ]]; then
            deb_url="https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_arm64/session-manager-plugin.deb"
        else
            deb_url="https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb"
        fi
        local tmpfile
        tmpfile=$(mktemp --suffix=.deb)
        curl -fsSL "$deb_url" -o "$tmpfile"
        sudo dpkg -i "$tmpfile"
        rm -f "$tmpfile"
    else
        local rpm_url
        if [[ "$arch" == "aarch64" ]]; then
            rpm_url="https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_arm64/session-manager-plugin.rpm"
        else
            rpm_url="https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm"
        fi
        local tmpfile
        tmpfile=$(mktemp --suffix=.rpm)
        curl -fsSL "$rpm_url" -o "$tmpfile"
        sudo yum install -y "$tmpfile"
        rm -f "$tmpfile"
    fi

    if command -v session-manager-plugin &>/dev/null; then
        print_success "SSM Session Manager plugin installed."
    else
        print_error "SSM Session Manager plugin installation failed."
        return 1
    fi
}

configure_s3_access() {
    print_step "Configuring S3 bucket access..."

    if ! command -v aws &>/dev/null; then
        print_error "AWS CLI is not installed. Please install it first."
        return 1
    fi

    echo -e "  ${BOLD}Testing S3 access...${NC}"
    if aws s3 ls &>/dev/null; then
        print_success "S3 access verified. Your buckets:"
        aws s3 ls | while read -r line; do
            echo -e "    ${CYAN}${line}${NC}"
        done
    else
        print_warn "Could not list S3 buckets. Check your credentials and permissions."
    fi

    if confirm "  Create a new S3 bucket?"; then
        read -rp "  Enter bucket name: " bucket_name
        if [[ -z "$bucket_name" ]]; then
            print_error "Bucket name cannot be empty."
            return 1
        fi

        local region
        region=$(aws configure get region 2>/dev/null)
        region=${region:-us-east-1}
        read -rp "  Region [${region}]: " bucket_region
        bucket_region=${bucket_region:-$region}

        if [[ "$bucket_region" == "us-east-1" ]]; then
            aws s3api create-bucket --bucket "$bucket_name" --region "$bucket_region"
        else
            aws s3api create-bucket --bucket "$bucket_name" --region "$bucket_region" \
                --create-bucket-configuration LocationConstraint="$bucket_region"
        fi

        if [[ $? -eq 0 ]]; then
            print_success "Bucket '${bucket_name}' created in ${bucket_region}."

            if confirm "  Enable versioning on this bucket?"; then
                aws s3api put-bucket-versioning --bucket "$bucket_name" \
                    --versioning-configuration Status=Enabled
                print_success "Versioning enabled on '${bucket_name}'."
            fi

            if confirm "  Block all public access on this bucket? (recommended)"; then
                aws s3api put-public-access-block --bucket "$bucket_name" \
                    --public-access-block-configuration \
                    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
                print_success "Public access blocked on '${bucket_name}'."
            fi
        else
            print_error "Failed to create bucket '${bucket_name}'."
        fi
    fi
}

install_cfn_helpers() {
    print_step "Installing CloudFormation helper scripts..."

    if [[ "$PKG" == "apt" ]]; then
        pkg_install python3-pip
        sudo pip3 install https://s3.amazonaws.com/cloudformation-examples/aws-cfn-bootstrap-py3-latest.tar.gz
    else
        pkg_install aws-cfn-bootstrap
    fi

    if command -v cfn-init &>/dev/null || [[ -f /opt/aws/bin/cfn-init ]]; then
        print_success "CloudFormation helper scripts installed (cfn-init, cfn-signal, cfn-get-metadata, cfn-hup)."
    else
        print_warn "CloudFormation helpers installed via pip. They may be in your Python path."
        echo -e "  ${BOLD}Tip:${NC} Check ${CYAN}/usr/local/bin/cfn-init${NC} or ${CYAN}/opt/aws/bin/cfn-init${NC}"
    fi
}
