function bw_get_totp -d "Get TOTP code from Bitwarden item" -a item_name
    ensure_bw_session; or return 1
    bw get totp "$item_name" 2>/dev/null
end
