function bw_get_username -d "Get username from Bitwarden item" -a item_name
    ensure_bw_session; or return 1
    bw get username "$item_name" 2>/dev/null
end
