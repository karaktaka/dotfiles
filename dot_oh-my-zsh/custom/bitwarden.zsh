#!/usr/bin/env zsh
# Universal Bitwarden helper functions
# Provides consistent secret retrieval across all shell modules

# Ensure Bitwarden CLI is available
if ! command -v bw &> /dev/null; then
  echo "⚠️  Bitwarden CLI (bw) not found. Install with: brew install bitwarden-cli"
  return
fi

_bw="$(which bw)"

# Ensure BW_SESSION is set, unlock if needed
# Returns 0 on success, 1 on failure
function ensure_bw_session() {
  if [[ -z "$BW_SESSION" ]]; then
    echo "🔐 Unlocking Bitwarden..."
    export BW_SESSION=$($_bw unlock --raw)
    if [[ -z "$BW_SESSION" ]]; then
      echo "❌ Failed to unlock Bitwarden"
      return 1
    fi
    $_bw sync --quiet
  fi
  return 0
}

# Get a secret from Bitwarden by item name and field
# Usage: bw_get_secret "Item Name" [field]
# field defaults to "password", can be "notes" or custom field name
function bw_get_secret() {
  local item_name="$1"
  local field="${2:-password}"

  ensure_bw_session || return 1

  if [[ "$field" == "password" ]]; then
    $_bw get password "$item_name" 2>/dev/null
  elif [[ "$field" == "notes" ]]; then
    $_bw get notes "$item_name" 2>/dev/null
  else
    $_bw get item "$item_name" 2>/dev/null | jq -r ".fields[] | select(.name==\"$field\") | .value"
  fi
}

# Get username from Bitwarden item
# Usage: bw_get_username "Item Name"
function bw_get_username() {
  local item_name="$1"
  ensure_bw_session || return 1
  $_bw get username "$item_name" 2>/dev/null
}

# Get TOTP code from Bitwarden item
# Usage: bw_get_totp "Item Name"
function bw_get_totp() {
  local item_name="$1"
  ensure_bw_session || return 1
  $_bw get totp "$item_name" 2>/dev/null
}

# Check if a secret exists in Bitwarden
# Usage: bw_has_secret "Item Name"
function bw_has_secret() {
  local item_name="$1"
  ensure_bw_session || return 1
  $_bw get item "$item_name" &>/dev/null
}

# Get an entire item as JSON
# Usage: bw_get_item "Item Name"
function bw_get_item() {
  local item_name="$1"
  ensure_bw_session || return 1
  $_bw get item "$item_name" 2>/dev/null
}

# Sync Bitwarden vault (useful after adding new items)
# Usage: bw_sync
function bw_sync() {
  ensure_bw_session || return 1
  $_bw sync
}
