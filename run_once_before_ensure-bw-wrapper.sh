#!/bin/bash
# Bootstrap the bw-session wrapper so chezmoi bitwarden templates can render
# before dot_local/bin/executable_bw-session is deployed by chezmoi apply.
# run_once_before_ ensures this runs before file targets on first install.
set -e
mkdir -p "$HOME/.local/bin"
cat > "$HOME/.local/bin/bw-session" << 'EOF'
#!/usr/bin/env bash
# Wrapper for bw CLI that injects BW_SESSION from the session file.
# Used by chezmoi's bitwarden template function (command: ~/.local/bin/bw-session).
BW_SESSION=$(cat ~/.bw_session 2>/dev/null) exec bw "$@"
EOF
chmod +x "$HOME/.local/bin/bw-session"
