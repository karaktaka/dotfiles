function bw_has_secret -d "Check if a secret exists in Bitwarden" -a item_name
    ensure_bw_session; or return 1
    bw get item "$item_name" &>/dev/null
end
