#!/usr/bin/env bash
# PermissionRequest gate: auto-approve operations targeting /tmp.
# Covers Write/Edit (file_path) and Bash rm/execute patterns.
# Reads from /tmp are already allowed by permissions-read.sh.

command -v jq &>/dev/null || exit 0

INPUT=$(cat)
TOOL=$(jq -r '.tool_name // ""' <<< "$INPUT")

allow() {
  jq -n --arg r "$1" \
    '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","permissionDecision":"allow","permissionDecisionReason":$r}}'
  exit 0
}

case "$TOOL" in
  Write|Edit)
    FILE=$(jq -r '.tool_input.file_path // ""' <<< "$INPUT")
    [[ "$FILE" == /tmp/* ]] && allow "/tmp writes are safe"
    ;;
  Bash)
    CMD=$(jq -r '.tool_input.command // ""' <<< "$INPUT")

    # Allow: executing scripts/files from /tmp
    [[ "$CMD" =~ ^(bash|sh|zsh|python3?|node|perl|ruby|chmod)[[:space:]]+/tmp/ ]] \
      && allow "/tmp script execution is safe"
    [[ "$CMD" =~ ^/tmp/ ]] \
      && allow "/tmp direct execution is safe"

    # Allow: rm when ALL non-flag args target /tmp (no collateral damage)
    if [[ "$CMD" =~ ^rm[[:space:]] ]]; then
      non_flag_args=$(awk '{for(i=2;i<=NF;i++) if($i!~/^-/) print $i}' <<< "$CMD")
      if [[ -n "$non_flag_args" ]] && ! grep -qv '^/tmp/' <<< "$non_flag_args"; then
        allow "/tmp cleanup is safe"
      fi
    fi
    ;;
esac

exit 0
