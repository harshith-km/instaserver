#!/bin/bash
# ============================================================
#  Environment File Management
# ============================================================

setup_envfile() {
    echo -e "\n${CYAN}── Environment File Management ──${NC}"

    echo -e "\n  Select an option:"
    echo -e "    1) Create a new .env file"
    echo -e "    2) Edit an existing .env file"
    echo -e "    3) View .env file (masked secrets)"
    echo -e "    4) Copy .env from another location"
    echo -e "    5) Set up .env encryption with age/sops"
    echo -e "    6) Back to main menu"
    read -rp "  Choice [1-6]: " env_choice

    case $env_choice in
        1) envfile_create ;;
        2) envfile_edit ;;
        3) envfile_view ;;
        4) envfile_copy ;;
        5) envfile_encrypt ;;
        6) return ;;
        *) print_error "Invalid choice."; return ;;
    esac
}

envfile_create() {
    print_step "Create a new .env file"

    read -rp "  Enter file path [default: /var/www/app/.env]: " env_path
    env_path=${env_path:-/var/www/app/.env}

    if [[ -f "$env_path" ]]; then
        if ! confirm "  File already exists. Overwrite?"; then
            print_warn "Aborted."
            return
        fi
    fi

    # Ensure parent directory exists
    local env_dir
    env_dir=$(dirname "$env_path")
    if [[ ! -d "$env_dir" ]]; then
        if confirm "  Directory $env_dir does not exist. Create it?"; then
            sudo mkdir -p "$env_dir"
            print_success "Directory created: $env_dir"
        else
            print_warn "Aborted."
            return
        fi
    fi

    local tmp_file
    tmp_file=$(mktemp)

    echo -e "\n  Enter environment variables as ${BOLD}KEY=value${NC} (type ${BOLD}done${NC} to finish):"

    while true; do
        read -rp "  > " line

        if [[ "$line" == "done" ]]; then
            break
        fi

        if [[ -z "$line" ]]; then
            continue
        fi

        # Validate KEY=value format
        if [[ ! "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
            print_error "Invalid format. Use KEY=value (KEY must start with a letter or underscore)."
            continue
        fi

        echo "$line" >> "$tmp_file"
        local key="${line%%=*}"
        print_success "Added: $key"
    done

    sudo cp "$tmp_file" "$env_path"
    rm -f "$tmp_file"

    sudo chmod 600 "$env_path"
    sudo chown "$(whoami):$(whoami)" "$env_path"

    print_success ".env file created at $env_path (permissions: 600)"
}

envfile_edit() {
    print_step "Edit an existing .env file"

    read -rp "  Enter .env file path: " env_path

    if [[ -z "$env_path" ]]; then
        print_error "No path provided."
        return
    fi

    if [[ ! -f "$env_path" ]]; then
        print_error "File not found: $env_path"
        return
    fi

    # Show current contents with masked values
    echo -e "\n  ${BOLD}Current contents (values masked):${NC}"
    while IFS= read -r line; do
        # Skip empty lines and comments
        if [[ -z "$line" || "$line" =~ ^# ]]; then
            echo -e "    $line"
            continue
        fi
        if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*) ]]; then
            local key="${BASH_REMATCH[1]}"
            local val="${BASH_REMATCH[2]}"
            if [[ ${#val} -le 3 ]]; then
                echo -e "    ${GREEN}${key}${NC}=***"
            else
                echo -e "    ${GREEN}${key}${NC}=${val:0:3}***"
            fi
        else
            echo -e "    $line"
        fi
    done < "$env_path"

    echo -e "\n  What would you like to do?"
    echo -e "    1) Add a new variable"
    echo -e "    2) Modify an existing variable"
    echo -e "    3) Delete a variable"
    read -rp "  Choice [1-3]: " edit_choice

    case $edit_choice in
        1)
            read -rp "  Enter new variable as KEY=value: " new_var
            if [[ ! "$new_var" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
                print_error "Invalid format. Use KEY=value."
                return
            fi
            echo "$new_var" | sudo tee -a "$env_path" > /dev/null
            local key="${new_var%%=*}"
            print_success "Variable $key added."
            ;;
        2)
            read -rp "  Enter the variable name to modify: " mod_key
            if [[ -z "$mod_key" ]]; then
                print_error "No variable name provided."
                return
            fi

            local current_val
            current_val=$(grep "^${mod_key}=" "$env_path" 2>/dev/null | head -1 | cut -d'=' -f2-)

            if [[ -z "$current_val" && ! $(grep -q "^${mod_key}=" "$env_path" 2>/dev/null; echo $?) == "0" ]]; then
                # Check if the key actually exists (could have empty value)
                if ! grep -q "^${mod_key}=" "$env_path" 2>/dev/null; then
                    print_error "Variable $mod_key not found."
                    return
                fi
            fi

            echo -e "  Current value: ${YELLOW}${current_val}${NC}"
            read -rp "  Enter new value: " new_val
            sudo sed -i "s|^${mod_key}=.*|${mod_key}=${new_val}|" "$env_path"
            print_success "Variable $mod_key updated."
            ;;
        3)
            read -rp "  Enter the variable name to delete: " del_key
            if [[ -z "$del_key" ]]; then
                print_error "No variable name provided."
                return
            fi

            if ! grep -q "^${del_key}=" "$env_path" 2>/dev/null; then
                print_error "Variable $del_key not found."
                return
            fi

            if confirm "  Are you sure you want to delete $del_key?"; then
                sudo sed -i "/^${del_key}=/d" "$env_path"
                print_success "Variable $del_key deleted."
            else
                print_warn "Aborted."
            fi
            ;;
        *)
            print_error "Invalid choice."
            ;;
    esac
}

envfile_view() {
    print_step "View .env file"

    read -rp "  Enter .env file path: " env_path

    if [[ -z "$env_path" ]]; then
        print_error "No path provided."
        return
    fi

    if [[ ! -f "$env_path" ]]; then
        print_error "File not found: $env_path"
        return
    fi

    echo -e "\n  ${BOLD}Contents of $env_path (values masked):${NC}"
    while IFS= read -r line; do
        # Skip empty lines and comments
        if [[ -z "$line" || "$line" =~ ^# ]]; then
            echo -e "    $line"
            continue
        fi
        if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*) ]]; then
            local key="${BASH_REMATCH[1]}"
            local val="${BASH_REMATCH[2]}"
            if [[ ${#val} -le 3 ]]; then
                echo -e "    ${GREEN}${key}${NC}=***"
            else
                echo -e "    ${GREEN}${key}${NC}=${val:0:3}***"
            fi
        else
            echo -e "    $line"
        fi
    done < "$env_path"

    if confirm "\n  Show unmasked values?"; then
        echo -e "\n  ${BOLD}Contents of $env_path (unmasked):${NC}"
        while IFS= read -r line; do
            echo -e "    $line"
        done < "$env_path"
    fi
}

envfile_copy() {
    print_step "Copy .env file"

    read -rp "  Enter source .env file path: " src_path

    if [[ -z "$src_path" ]]; then
        print_error "No source path provided."
        return
    fi

    if [[ ! -f "$src_path" ]]; then
        print_error "Source file not found: $src_path"
        return
    fi

    read -rp "  Enter destination path: " dst_path

    if [[ -z "$dst_path" ]]; then
        print_error "No destination path provided."
        return
    fi

    if [[ -f "$dst_path" ]]; then
        if ! confirm "  Destination file already exists. Overwrite?"; then
            print_warn "Aborted."
            return
        fi
    fi

    # Ensure parent directory exists
    local dst_dir
    dst_dir=$(dirname "$dst_path")
    if [[ ! -d "$dst_dir" ]]; then
        if confirm "  Directory $dst_dir does not exist. Create it?"; then
            sudo mkdir -p "$dst_dir"
            print_success "Directory created: $dst_dir"
        else
            print_warn "Aborted."
            return
        fi
    fi

    sudo cp "$src_path" "$dst_path"
    sudo chmod 600 "$dst_path"
    print_success ".env file copied to $dst_path (permissions: 600)"
}

envfile_encrypt() {
    echo -e "\n${CYAN}── .env Encryption with age ──${NC}"

    # Install age if not present
    if ! command -v age &>/dev/null; then
        print_step "Installing age..."
        if [[ "$PKG" == "apt" ]]; then
            pkg_install age
        else
            pkg_install age || {
                print_warn "age not available in default repos. Installing from GitHub..."
                local age_ver="v1.1.1"
                local age_url="https://github.com/FiloSottile/age/releases/download/${age_ver}/age-${age_ver}-linux-amd64.tar.gz"
                curl -sL "$age_url" -o /tmp/age.tar.gz
                sudo tar -xzf /tmp/age.tar.gz -C /usr/local/bin --strip-components=1 age/age age/age-keygen
                rm -f /tmp/age.tar.gz
            }
        fi
        if command -v age &>/dev/null; then
            print_success "age installed successfully."
        else
            print_error "Failed to install age."
            return
        fi
    else
        print_success "age is already installed."
    fi

    local key_dir="$HOME/.config/age"
    local key_file="$key_dir/keys.txt"

    echo -e "\n  Select an option:"
    echo -e "    1) Generate age key pair"
    echo -e "    2) Encrypt a .env file"
    echo -e "    3) Decrypt a .env file"
    echo -e "    4) Show public key for sharing"
    echo -e "    5) Back"
    read -rp "  Choice [1-5]: " enc_choice

    case $enc_choice in
        1)
            print_step "Generating age key pair..."
            if [[ -f "$key_file" ]]; then
                print_warn "Key file already exists at $key_file"
                if ! confirm "  Generate a new key pair? (old key will be backed up)"; then
                    return
                fi
                cp "$key_file" "${key_file}.bak.$(date +%s)"
                print_success "Old key backed up."
            fi

            mkdir -p "$key_dir"
            chmod 700 "$key_dir"
            age-keygen -o "$key_file" 2>&1
            chmod 600 "$key_file"
            print_success "Key pair generated at $key_file"

            local pub_key
            pub_key=$(grep "^# public key:" "$key_file" | awk '{print $4}')
            echo -e "\n  ${BOLD}Public key:${NC} ${GREEN}${pub_key}${NC}"
            echo -e "  Share this public key with others who need to encrypt files for you."
            ;;
        2)
            if [[ ! -f "$key_file" ]]; then
                print_error "No age key found. Generate a key pair first (option 1)."
                return
            fi

            read -rp "  Enter .env file path to encrypt: " enc_path
            if [[ -z "$enc_path" || ! -f "$enc_path" ]]; then
                print_error "File not found: $enc_path"
                return
            fi

            local pub_key
            pub_key=$(grep "^# public key:" "$key_file" | awk '{print $4}')
            local enc_output="${enc_path}.age"

            print_step "Encrypting $enc_path..."
            age -r "$pub_key" -o "$enc_output" "$enc_path"
            chmod 600 "$enc_output"
            print_success "Encrypted file saved to $enc_output"

            if confirm "  Remove the original unencrypted file?"; then
                sudo rm -f "$enc_path"
                print_success "Original file removed."
            fi
            ;;
        3)
            if [[ ! -f "$key_file" ]]; then
                print_error "No age key found. Cannot decrypt without the private key."
                return
            fi

            read -rp "  Enter encrypted file path (*.age): " dec_path
            if [[ -z "$dec_path" || ! -f "$dec_path" ]]; then
                print_error "File not found: $dec_path"
                return
            fi

            local dec_output="${dec_path%.age}"
            if [[ "$dec_output" == "$dec_path" ]]; then
                dec_output="${dec_path}.decrypted"
            fi

            read -rp "  Output file path [default: $dec_output]: " custom_output
            dec_output=${custom_output:-$dec_output}

            print_step "Decrypting $dec_path..."
            age -d -i "$key_file" -o "$dec_output" "$dec_path"
            chmod 600 "$dec_output"
            print_success "Decrypted file saved to $dec_output"
            ;;
        4)
            if [[ ! -f "$key_file" ]]; then
                print_error "No age key found. Generate a key pair first (option 1)."
                return
            fi

            local pub_key
            pub_key=$(grep "^# public key:" "$key_file" | awk '{print $4}')
            echo -e "\n  ${BOLD}Your public key:${NC}"
            echo -e "  ${GREEN}${pub_key}${NC}"
            echo -e "\n  Share this key with anyone who needs to encrypt files for you."
            ;;
        5) return ;;
        *) print_error "Invalid choice." ;;
    esac
}
