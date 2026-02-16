function ensure_bw_session -d "Ensure Bitwarden session is active, unlock if needed"
    if not command -q bw
        echo "⚠️  Bitwarden CLI (bw) not found. Install it via your package manager (brew, pacman, etc.)" >&2
        return 1
    end

    set -l session_file "$HOME/.bw_session"

    # Try to load existing session from file if not in environment
    if test -z "$BW_SESSION"; and test -f "$session_file"
        set -gx BW_SESSION (cat "$session_file")
    end

    # Validate session is still active
    if test -n "$BW_SESSION"
        if bw unlock --check &>/dev/null
            return 0
        else
            # Session expired, clear it
            set -e BW_SESSION
            rm -f "$session_file"
        end
    end

    # Need to unlock
    echo "🔐 Unlocking Bitwarden..." >&2
    set -gx BW_SESSION (bw unlock --raw)
    if test -z "$BW_SESSION"
        echo "❌ Failed to unlock Bitwarden" >&2
        return 1
    end

    # Persist raw session token (shell-agnostic format, shared with zsh)
    printf '%s' "$BW_SESSION" >"$session_file"
    chmod 600 "$session_file"

    bw sync --quiet
    echo "✅ Bitwarden session saved (reusable across terminals)" >&2
    return 0
end
