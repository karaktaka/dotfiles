#!/usr/bin/env bash
# no-plans-folder.sh: Block writes to plans/ folders in non-Implementations repos.
# Plans belong in ~/workspace/git/Implementations/<repo>/plans/ — not in per-repo docs/plans/.

command -v jq &>/dev/null || exit 0

INPUT=$(cat)
TOOL=$(jq -r '.tool_name // ""' <<< "$INPUT")

case "$TOOL" in
  Edit|Write|NotebookEdit) ;;
  *) exit 0 ;;
esac

FILE_PATH=$(jq -r '.tool_input.file_path // ""' <<< "$INPUT")
[[ -z "$FILE_PATH" ]] && exit 0

# Check if path contains a /plans/ component
if ! echo "$FILE_PATH" | grep -qE '(^|/)plans(/|$)'; then
    exit 0
fi

IMPLEMENTATIONS_PATH="$HOME/workspace/git/Implementations"

# Allow writes inside the Implementations repo
[[ "$FILE_PATH" == "$IMPLEMENTATIONS_PATH"* ]] && exit 0

# Allow Claude Code's own internal plans directory (~/.claude/plans/)
[[ "$FILE_PATH" == "$HOME/.claude/plans/"* ]] && exit 0

jq -n --arg ip "$IMPLEMENTATIONS_PATH" --arg fp "$FILE_PATH" \
  '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":("Plans folder blocked: write plans to " + $ip + "/<repo>/plans/ instead. Tried to write: " + $fp)}}'
exit 0
