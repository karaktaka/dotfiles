# Fish shell configuration
# Managed by chezmoi

# Source system config if available (CachyOS, etc.)
if test -f /usr/share/cachyos-fish-config/cachyos-config.fish
    source /usr/share/cachyos-fish-config/cachyos-config.fish
end

# Key bindings
bind alt-right nextd-or-forward-word
bind alt-left prevd-or-backward-word

bind alt-backspace backward-kill-word
bind alt-delete kill-word
