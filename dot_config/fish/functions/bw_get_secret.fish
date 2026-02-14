function bw_get_secret -d "Get secret from Bitwarden by item name" -a item_name field
    test -z "$field"; and set field password

    ensure_bw_session; or return 1

    switch $field
        case password
            bw get password "$item_name" 2>/dev/null
        case notes
            bw get notes "$item_name" 2>/dev/null
        case '*'
            bw get item "$item_name" 2>/dev/null | jq -r ".fields[] | select(.name==\"$field\") | .value"
    end
end
