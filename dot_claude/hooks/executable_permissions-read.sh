#!/usr/bin/env bash
# Permissions gate for the Read tool.
# Deny: .env files. Allow: trusted home-dir paths.

command -v jq &>/dev/null || exit 0

INPUT=$(cat)
[[ "$(jq -r '.tool_name // ""' <<< "$INPUT")" != "Read" ]] && exit 0

allow() { jq -n --arg r "$1" '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":$r}}'; exit 0; }
deny()  { jq -n --arg r "$1" '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":$r}}'; exit 0; }

FILE=$(jq -r '.tool_input.file_path // ""' <<< "$INPUT")
FILE="${FILE/#\~/$HOME}"  # expand leading ~

# DENY: .env files (any directory depth)
BASE=$(basename "$FILE")
[[ "$BASE" == ".env" || "$BASE" == .env.* ]] && deny ".env file is protected"

# ALLOW: trusted home-dir paths
case "$FILE" in
  "${HOME}/CLAUDE"*|\
  "${HOME}/.claude"*|\
  "${HOME}/.local"*|\
  "${HOME}/.gitconfig"|\
  "${HOME}/personal"*|\
  "${HOME}/workspace"*|\
  /tmp*) allow "Trusted path" ;;
esac

# Work: additional trusted paths
[[ "${CLAUDE_CODE_USE_BEDROCK:-false}" == "true" ]] && case "$FILE" in
  "${HOME}/.aws/config") allow "AWS config (read-only)" ;;
esac

exit 0
