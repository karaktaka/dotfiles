function bw_sync -d "Sync Bitwarden vault"
    ensure_bw_session; or return 1
    bw sync
end
