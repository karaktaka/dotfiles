#!/usr/bin/env bash
# hook-lib.sh — shared library for Claude Code PreToolUse / PermissionRequest hooks.
# Source at the top of each hook (after the shebang):
#   source ~/.claude/hooks/hook-lib.sh || exit 0
#
# Provides variables: $TOOL, $COMMAND, $FILE_PATH, $TOOL_INPUT_PATH, $CMD_NAME, $AGENT_ID, $INPUT
# Provides functions:  allow(), deny(), ask(), rewrite_and_allow()
#
# For PermissionRequest hooks, set _HOOK_EVENT before sourcing:
#   _HOOK_EVENT="PermissionRequest"

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && { echo "hook-lib.sh: source this file, do not execute it directly" >&2; exit 1; }

command -v jq &>/dev/null || exit 0

INPUT=$(cat)

# Parse all commonly needed fields in a single jq invocation.
# NUL-delimited output handles newlines and special characters in any field value.
{
  IFS= read -r -d '' TOOL
  IFS= read -r -d '' COMMAND
  IFS= read -r -d '' FILE_PATH
  IFS= read -r -d '' TOOL_INPUT_PATH
  IFS= read -r -d '' AGENT_ID
} < <(jq -rj '
  (.tool_name           // "") + "\u0000" +
  (.tool_input.command  // "") + "\u0000" +
  (.tool_input.file_path // "") + "\u0000" +
  (.tool_input.path     // "") + "\u0000" +
  (.agent_id            // "") + "\u0000"' <<< "$INPUT")

# CMD_NAME: first non-assignment token of COMMAND (used by Bash hooks only).
if [[ "$TOOL" == "Bash" && -n "$COMMAND" ]]; then
  # Strip leading subshell/brace-group syntax so CMD_NAME reflects the actual command
  _cmd_for_parse=$(sed 's/^[({[:space:]]*//' <<< "$COMMAND")
  _raw=$(awk '{for(i=1;i<=NF;i++) if($i!~/^[A-Za-z_][A-Za-z0-9_]*=/) {print $i; exit}}' <<< "$_cmd_for_parse")
  CMD_NAME=$(basename "$_raw" 2>/dev/null)
fi

_HOOK_EVENT="${_HOOK_EVENT:-PreToolUse}"

allow() {
  jq -n --arg e "$_HOOK_EVENT" --arg r "$1" \
    '{"hookSpecificOutput":{"hookEventName":$e,"permissionDecision":"allow","permissionDecisionReason":$r}}'
  exit 0
}

deny() {
  jq -n --arg e "$_HOOK_EVENT" --arg r "$1" --arg ctx "${2:-}" \
    '{"hookSpecificOutput":{"hookEventName":$e,"permissionDecision":"deny","permissionDecisionReason":$r}}
     | if $ctx != "" then .hookSpecificOutput.additionalContext = ($ctx | gsub(" \\| "; "\n")) else . end'
  exit 0
}

ask() {
  jq -n --arg e "$_HOOK_EVENT" --arg r "$1" \
    '{"hookSpecificOutput":{"hookEventName":$e,"permissionDecision":"ask","permissionDecisionReason":$r}}'
  exit 0
}

rewrite_and_allow() {
  local new_cmd="$1" reason="$2"
  jq -n --arg e "$_HOOK_EVENT" --arg r "$reason" --arg cmd "$new_cmd" --argjson inp "$INPUT" \
    '{"hookSpecificOutput":{"hookEventName":$e,"permissionDecision":"allow","permissionDecisionReason":$r,"updatedInput":($inp.tool_input | .command = $cmd)}}'
  exit 0
}
