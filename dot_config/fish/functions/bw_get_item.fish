function bw_get_item -d "Get entire Bitwarden item as JSON" -a item_name
    ensure_bw_session; or return 1
    bw get item "$item_name" 2>/dev/null
end
