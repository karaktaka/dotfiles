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
if [[ "$FILE_PATH" == "$IMPLEMENTATIONS_PATH"* ]]; then
    exit 0
fi

REASON="Plans folder blocked: write plans to $IMPLEMENTATIONS_PATH/<repo>/plans/ instead. Tried to write: $FILE_PATH"
jq -n --arg r "$REASON" \
  '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":$r}}'
exit 0
