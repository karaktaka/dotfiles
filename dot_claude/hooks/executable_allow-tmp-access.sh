#!/usr/bin/env bash
# PermissionRequest gate: auto-approve operations targeting /tmp.
# Covers Write/Edit (file_path) and Bash rm/execute patterns.
# Reads from /tmp are already allowed by permissions-read.sh.

_HOOK_EVENT="PermissionRequest"
source ~/.claude/hooks/hook-lib.sh || exit 0

case "$TOOL" in
  Write|Edit)
    [[ "$FILE_PATH" == /tmp/* ]] && allow "/tmp writes are safe"
    ;;
  Bash)
    # Allow: executing scripts/files from /tmp
    [[ "$COMMAND" =~ ^(bash|sh|zsh|python3?|node|perl|ruby|chmod)[[:space:]]+/tmp/ ]] \
      && allow "/tmp script execution is safe"
    [[ "$COMMAND" =~ ^/tmp/ ]] \
      && allow "/tmp direct execution is safe"

    # Allow: rm when ALL non-flag args target /tmp (no collateral damage).
    # Reject paths containing .. to prevent traversal like /tmp/../home/user/file.
    if [[ "$COMMAND" =~ ^rm[[:space:]] ]]; then
      non_flag_args=$(awk '{for(i=2;i<=NF;i++) if($i!~/^-/) print $i}' <<< "$COMMAND")
      if [[ -n "$non_flag_args" ]] && \
         ! grep -qv '^/tmp/' <<< "$non_flag_args" && \
         ! grep -q '\.\.' <<< "$non_flag_args"; then
        allow "/tmp cleanup is safe"
      fi
    fi
    ;;
esac

exit 0
