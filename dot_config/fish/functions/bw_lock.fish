function bw_lock -d "Lock Bitwarden and clear persisted session"
    bw lock &>/dev/null
    set -e BW_SESSION
    rm -f "$HOME/.bw_session"
    echo "🔒 Bitwarden locked and session cleared" >&2
end
