#!/usr/bin/env zsh
# Confluence helpers — wraps `mark` CLI with Bitwarden-backed auth

# Wrap `mark` to auto-inject PAT from Bitwarden
# Usage: mark -f mypage.md (all normal mark flags work)
function mark() {
  if [[ -z "$MARK_PASSWORD" ]]; then
    MARK_PASSWORD=$(bw_get_secret "Confluence API Token") || {
      echo "❌ Failed to get Confluence token from Bitwarden" >&2
      return 1
    }
    export MARK_PASSWORD
  fi

  command mark "$@"
}
