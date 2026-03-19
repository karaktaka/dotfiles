#!/usr/bin/env bash
# Permissions gate for the WebFetch tool.
# Default: no decision (Claude Code default applies).
# Work: allow internal GitLab domain.

source ~/.claude/hooks/hook-lib.sh || exit 0

[[ "$TOOL" != "WebFetch" ]] && exit 0

[[ "${CLAUDE_CODE_USE_BEDROCK:-false}" == "true" ]] && {
  URL=$(jq -r '.tool_input.url // ""' <<< "$INPUT")
  [[ "$URL" == *"gitlab.example.com"* ]] && allow "Internal GitLab"
}

exit 0
