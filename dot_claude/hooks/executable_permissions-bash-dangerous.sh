#!/usr/bin/env bash
# Permissions gate for explicitly dangerous shell operations: rm, curl, wget.
# All require explicit user confirmation.

command -v jq &>/dev/null || exit 0

INPUT=$(cat)
[[ "$(jq -r '.tool_name // ""' <<< "$INPUT")" != "Bash" ]] && exit 0

COMMAND=$(jq -r '.tool_input.command // ""' <<< "$INPUT")
CMD_NAME=$(basename "${COMMAND%% *}" 2>/dev/null || echo "${COMMAND%% *}")

ask() {
  jq -n --arg r "$1" \
    '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":$r}}'
  exit 0
}

case "$CMD_NAME" in
  rm)   ask "File deletion — confirm path and scope" ;;
  curl) ask "Network request — confirm URL and intent" ;;
  wget) ask "Network download — confirm URL and intent" ;;
esac

exit 0
