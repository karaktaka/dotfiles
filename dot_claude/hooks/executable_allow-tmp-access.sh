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
      read -ra _rm_words <<< "$COMMAND"
      _all_tmp=true _has_args=false
      for _arg in "${_rm_words[@]:1}"; do
        [[ "$_arg" == -* ]] && continue
        _has_args=true
        [[ "$_arg" != /tmp/* || "$_arg" == *..* ]] && { _all_tmp=false; break; }
      done
      [[ "$_has_args" == true && "$_all_tmp" == true ]] && allow "/tmp cleanup is safe"
    fi
    ;;
esac

exit 0
