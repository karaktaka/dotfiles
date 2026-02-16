#!/usr/bin/env bash
# Wrapper script for mcp-atlassian MCP server
# Fetches Atlassian PAT from Bitwarden, then launches the MCP server via uvx
#
# Used by Claude Code as an MCP server command.
# Requires: bw (Bitwarden CLI), uvx, ~/.bw_session (from ensure_bw_session)

set -euo pipefail

BW_SESSION_FILE="${HOME}/.bw_session"
BW="$(command -v bw)"
UVX="$(command -v uvx)"

# Load persisted Bitwarden session
if [[ -f "$BW_SESSION_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$BW_SESSION_FILE"
fi

if [[ -z "${BW_SESSION:-}" ]]; then
  echo "No Bitwarden session found. Run 'ensure_bw_session' in a terminal first." >&2
  exit 1
fi

export BW_SESSION

# Verify session is still valid
if ! "$BW" unlock --check &>/dev/null; then
  echo "Bitwarden session expired. Run 'ensure_bw_session' in a terminal first." >&2
  exit 1
fi

# Fetch the shared Atlassian PAT
TOKEN=$("$BW" get password "Jira API Token" 2>/dev/null)
if [[ -z "$TOKEN" ]]; then
  echo "Failed to retrieve 'Jira API Token' from Bitwarden." >&2
  exit 1
fi

export JIRA_URL="https://jira.example.com"
export JIRA_PERSONAL_TOKEN="$TOKEN"
export CONFLUENCE_URL="https://wiki.example.com"
export CONFLUENCE_PERSONAL_TOKEN="$TOKEN"

exec "$UVX" mcp-atlassian
