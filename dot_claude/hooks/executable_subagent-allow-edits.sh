#!/usr/bin/env bash
# Subagents have an agent_id in the hook input; the parent session does not.
_HOOK_EVENT="PermissionRequest"
source ~/.claude/hooks/hook-lib.sh || exit 0

[[ -z "$AGENT_ID" ]] && exit 0

case "$TOOL" in
  Edit|Write) allow "inside subagent - edit pre-approved by implementation spec" ;;
esac
