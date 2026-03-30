#!/bin/bash
# ============================================================
#  Git Configuration
# ============================================================

setup_git() {
    echo -e "\n${CYAN}── Git Configuration ──${NC}"

    read -rp "  Enter Git username: " git_name
    if [[ -n "$git_name" ]]; then
        git config --global user.name "$git_name"
    fi

    read -rp "  Enter Git email: " git_email
    if [[ -n "$git_email" ]]; then
        git config --global user.email "$git_email"
    fi

    git config --global init.defaultBranch main
    git config --global pull.rebase false

    if confirm "  Set up Git credential cache (15 min)?"; then
        git config --global credential.helper 'cache --timeout=900'
    fi

    if confirm "  Generate SSH key for Git (GitHub/GitLab)?"; then
        local key_email="${git_email:-$USER@$(hostname)}"
        read -rp "  Key type - 1) ed25519 (recommended) 2) rsa [default: 1]: " key_type
        key_type=${key_type:-1}

        if [[ "$key_type" == "1" ]]; then
            ssh-keygen -t ed25519 -C "$key_email" -f "$HOME/.ssh/id_ed25519" -N ""
            print_success "SSH key generated: $HOME/.ssh/id_ed25519.pub"
            echo -e "\n  ${BOLD}Your public key (add to GitHub/GitLab):${NC}"
            cat "$HOME/.ssh/id_ed25519.pub"
        else
            ssh-keygen -t rsa -b 4096 -C "$key_email" -f "$HOME/.ssh/id_rsa" -N ""
            print_success "SSH key generated: $HOME/.ssh/id_rsa.pub"
            echo -e "\n  ${BOLD}Your public key (add to GitHub/GitLab):${NC}"
            cat "$HOME/.ssh/id_rsa.pub"
        fi
    fi

    print_success "Git configured."
}
