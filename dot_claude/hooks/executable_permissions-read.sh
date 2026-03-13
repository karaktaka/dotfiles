#!/usr/bin/env bash
# Permissions gate for Read, Grep, and Glob tools.
# Deny: .env files. Allow: trusted home-dir paths.

command -v jq &>/dev/null || exit 0

INPUT=$(cat)
TOOL=$(jq -r '.tool_name // ""' <<< "$INPUT")

case "$TOOL" in
  Read)           PATH_KEY="file_path" ;;
  Grep|Glob)      PATH_KEY="path" ;;
  *)              exit 0 ;;
esac

allow() { jq -n --arg r "$1" '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":$r}}'; exit 0; }
deny()  { jq -n --arg r "$1" '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":$r}}'; exit 0; }

FILE=$(jq -r --arg k "$PATH_KEY" '.tool_input[$k] // ""' <<< "$INPUT")
FILE="${FILE/#\~/$HOME}"  # expand leading ~

# DENY: .env files (Read only — Grep/Glob on a directory is fine)
if [[ "$TOOL" == "Read" ]]; then
  BASE=$(basename "$FILE")
  [[ "$BASE" == ".env" || "$BASE" == .env.* ]] && deny ".env file is protected"
fi

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
