#!/usr/bin/env bash
# Permissions gate for the WebFetch tool.
# Default: no decision (Claude Code default applies).
# Work: allow internal GitLab domain.

command -v jq &>/dev/null || exit 0

INPUT=$(cat)
[[ "$(jq -r '.tool_name // ""' <<< "$INPUT")" != "WebFetch" ]] && exit 0

allow() { jq -n --arg r "$1" '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":$r}}'; exit 0; }

[[ "${CLAUDE_CODE_USE_BEDROCK:-false}" == "true" ]] && {
  URL=$(jq -r '.tool_input.url // ""' <<< "$INPUT")
  [[ "$URL" == *"gitlab.example.com"* ]] && allow "Internal GitLab"
}

exit 0
