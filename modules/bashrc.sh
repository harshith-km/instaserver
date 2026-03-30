#!/bin/bash
# ============================================================
#  .bashrc Customization
# ============================================================

setup_bashrc() {
    echo -e "\n${CYAN}── .bashrc Customization ──${NC}"

    local bashrc="$HOME/.bashrc"
    local backup="$HOME/.bashrc.backup.$(date +%Y%m%d%H%M%S)"

    # Backup first
    cp "$bashrc" "$backup" 2>/dev/null || true
    print_success "Backup created: $backup"

    echo -e "\n  Select what to add/modify:"
    echo -e "    1) Add useful aliases"
    echo -e "    2) Customize PS1 prompt (colored, with git branch)"
    echo -e "    3) Add environment variables"
    echo -e "    4) Set default editor"
    echo -e "    5) Add PATH entries"
    echo -e "    6) Add custom command/line"
    echo -e "    7) Enable history improvements"
    echo -e "    8) Apply a full recommended preset"
    echo -e "    9) View current .bashrc"
    echo -e "   10) Back to main menu"
    read -rp "  Choice [1-10]: " bashrc_choice

    case $bashrc_choice in
        1) bashrc_aliases ;;
        2) bashrc_prompt ;;
        3) bashrc_env_vars ;;
        4) bashrc_editor ;;
        5) bashrc_path ;;
        6) bashrc_custom_line ;;
        7) bashrc_history ;;
        8) bashrc_full_preset ;;
        9)
            echo -e "\n${BOLD}--- Current .bashrc ---${NC}"
            cat "$bashrc"
            echo -e "${BOLD}--- End ---${NC}"
            ;;
        10) return ;;
        *) print_error "Invalid choice."; return ;;
    esac

    echo -e "\n  Run ${CYAN}source ~/.bashrc${NC} or open a new terminal to apply changes."
}

bashrc_aliases() {
    print_step "Adding useful aliases..."

    local bashrc="$HOME/.bashrc"
    local marker="# --- EC2 Setup: Aliases ---"

    if grep -q "$marker" "$bashrc" 2>/dev/null; then
        print_warn "Aliases already added. Skipping."
        return
    fi

    cat >> "$bashrc" <<'ALIASES'

# --- EC2 Setup: Aliases ---
alias ll='ls -alFh --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias df='df -h'
alias du='du -sh'
alias free='free -h'
alias ports='sudo netstat -tlnp'
alias myip='curl -s ifconfig.me && echo'
alias reload='source ~/.bashrc'

# Docker aliases
alias dc='docker compose'
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dlog='docker logs -f'

# PM2 aliases
alias pm2l='pm2 list'
alias pm2log='pm2 logs'

# Systemd aliases
alias sc='sudo systemctl'
alias scr='sudo systemctl restart'
alias scs='sudo systemctl status'

# Nginx aliases
alias nginx-t='sudo nginx -t'
alias nginx-r='sudo nginx -t && sudo systemctl reload nginx'
ALIASES

    print_success "Aliases added to .bashrc"
    echo -e "  Added: ll, la, .., ..., ports, myip, reload, dc, dps, pm2l, sc, nginx-t, etc."
}

bashrc_prompt() {
    print_step "Customizing PS1 prompt..."

    local bashrc="$HOME/.bashrc"
    local marker="# --- EC2 Setup: PS1 Prompt ---"

    if grep -q "$marker" "$bashrc" 2>/dev/null; then
        print_warn "Custom prompt already added. Skipping."
        return
    fi

    echo -e "\n  Select prompt style:"
    echo -e "    1) Minimal: ${GREEN}user@host${NC}:${BLUE}~/dir${NC}\$ "
    echo -e "    2) With Git branch: ${GREEN}user@host${NC}:${BLUE}~/dir${NC} ${YELLOW}(main)${NC}\$ "
    echo -e "    3) Fancy multi-info: [time] user@host:dir (git) \$"
    read -rp "  Choice [1-3, default=2]: " prompt_style
    prompt_style=${prompt_style:-2}

    case $prompt_style in
        1)
            cat >> "$bashrc" <<'PROMPT1'

# --- EC2 Setup: PS1 Prompt ---
PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
PROMPT1
            ;;
        2)
            cat >> "$bashrc" <<'PROMPT2'

# --- EC2 Setup: PS1 Prompt ---
parse_git_branch() {
    git branch 2>/dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}
PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[33m\]$(parse_git_branch)\[\033[00m\]\$ '
PROMPT2
            ;;
        3)
            cat >> "$bashrc" <<'PROMPT3'

# --- EC2 Setup: PS1 Prompt ---
parse_git_branch() {
    git branch 2>/dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}
PS1='\[\033[0;90m\][\t]\[\033[00m\] \[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[33m\]$(parse_git_branch)\[\033[00m\]\n\$ '
PROMPT3
            ;;
    esac

    print_success "PS1 prompt customized."
}

bashrc_env_vars() {
    print_step "Adding environment variables..."

    local bashrc="$HOME/.bashrc"

    echo -e "  Enter environment variables one per line."
    echo -e "  Format: KEY=value"
    echo -e "  Type ${BOLD}done${NC} when finished.\n"

    while true; do
        read -rp "  > " env_line
        if [[ "$env_line" == "done" || -z "$env_line" ]]; then
            break
        fi
        if [[ "$env_line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
            echo "export $env_line" >> "$bashrc"
            print_success "Added: export $env_line"
        else
            print_error "Invalid format. Use KEY=value"
        fi
    done
}

bashrc_editor() {
    print_step "Setting default editor..."

    echo -e "  Select editor:"
    echo -e "    1) vim"
    echo -e "    2) nano"
    echo -e "    3) Custom"
    read -rp "  Choice [1-3, default=1]: " editor_choice
    editor_choice=${editor_choice:-1}

    local editor
    case $editor_choice in
        1) editor="vim" ;;
        2) editor="nano" ;;
        3)
            read -rp "  Enter editor command: " editor
            ;;
    esac

    local bashrc="$HOME/.bashrc"
    echo "" >> "$bashrc"
    echo "# --- EC2 Setup: Default Editor ---" >> "$bashrc"
    echo "export EDITOR=$editor" >> "$bashrc"
    echo "export VISUAL=$editor" >> "$bashrc"

    print_success "Default editor set to: $editor"
}

bashrc_path() {
    print_step "Adding PATH entries..."

    local bashrc="$HOME/.bashrc"

    echo -e "  Enter directories to add to PATH."
    echo -e "  Type ${BOLD}done${NC} when finished.\n"

    while true; do
        read -rp "  Directory: " path_entry
        if [[ "$path_entry" == "done" || -z "$path_entry" ]]; then
            break
        fi
        echo "export PATH=\"$path_entry:\$PATH\"" >> "$bashrc"
        print_success "Added to PATH: $path_entry"
    done
}

bashrc_custom_line() {
    print_step "Adding custom line to .bashrc..."

    local bashrc="$HOME/.bashrc"

    echo -e "  Enter the line to add (it will be appended as-is):"
    read -rp "  > " custom_line

    if [[ -n "$custom_line" ]]; then
        echo "" >> "$bashrc"
        echo "$custom_line" >> "$bashrc"
        print_success "Added: $custom_line"
    fi
}

bashrc_history() {
    print_step "Improving bash history settings..."

    local bashrc="$HOME/.bashrc"
    local marker="# --- EC2 Setup: History ---"

    if grep -q "$marker" "$bashrc" 2>/dev/null; then
        print_warn "History settings already added. Skipping."
        return
    fi

    cat >> "$bashrc" <<'HISTORY'

# --- EC2 Setup: History ---
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth:erasedups
HISTTIMEFORMAT="%F %T  "
shopt -s histappend
PROMPT_COMMAND="history -a; $PROMPT_COMMAND"
HISTORY

    print_success "History improvements added (10k entries, timestamps, dedup, append mode)."
}

bashrc_full_preset() {
    print_step "Applying full recommended .bashrc preset..."
    bashrc_aliases
    bashrc_prompt
    bashrc_history
    bashrc_editor

    local bashrc="$HOME/.bashrc"
    local marker="# --- EC2 Setup: Misc ---"

    if ! grep -q "$marker" "$bashrc" 2>/dev/null; then
        cat >> "$bashrc" <<'MISC'

# --- EC2 Setup: Misc ---
# Auto-cd into directories
shopt -s autocd 2>/dev/null
# Correct minor typos in cd
shopt -s cdspell 2>/dev/null
# Case-insensitive globbing
shopt -s nocaseglob 2>/dev/null
# Better tab completion
bind 'set show-all-if-ambiguous on'
bind 'set completion-ignore-case on'

# Display system info on login
echo ""
echo -e "\033[1;36m$(hostname)\033[0m | $(uname -r) | $(date)"
echo -e "IP: $(curl -s --max-time 2 ifconfig.me 2>/dev/null || echo 'N/A') | Uptime:$(uptime -p 2>/dev/null || uptime)"
echo -e "Disk: $(df -h / | awk 'NR==2{print $3"/"$2" ("$5")"}') | RAM: $(free -h | awk 'NR==2{print $3"/"$2}')"
echo ""
MISC
    fi

    print_success "Full .bashrc preset applied."
}
