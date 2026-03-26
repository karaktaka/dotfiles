#!/usr/bin/env bash
# subagent-allow-edits.sh — auto-approve Edit/Write when running inside a subagent.
# Subagents have an agent_id in the hook input; the parent session does not.
_HOOK_EVENT="PermissionRequest"
source ~/.claude/hooks/hook-lib.sh || exit 0

AGENT_ID=$(jq -r '.agent_id // empty' <<< "$INPUT")

[[ -n "$AGENT_ID" ]] && [[ "$TOOL" == "Edit" || "$TOOL" == "Write" ]] && \
  allow "inside subagent - edit pre-approved by implementation spec"
