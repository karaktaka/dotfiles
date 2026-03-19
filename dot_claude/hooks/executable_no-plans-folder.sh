#!/usr/bin/env bash
# no-plans-folder.sh: Block writes to plans/ folders in non-Implementations repos.
# Plans belong in ~/workspace/git/Implementations/<repo>/plans/ — not in per-repo docs/plans/.

source ~/.claude/hooks/hook-lib.sh || exit 0

case "$TOOL" in
  Edit|Write|NotebookEdit) ;;
  *) exit 0 ;;
esac

[[ -z "$FILE_PATH" ]] && exit 0

# Check if path contains a /plans/ component
if [[ ! "$FILE_PATH" =~ (^|/)plans(/|$) ]]; then
  exit 0
fi

IMPLEMENTATIONS_PATH="$HOME/workspace/git/Implementations"

# Allow writes inside the Implementations repo
[[ "$FILE_PATH" == "$IMPLEMENTATIONS_PATH"* ]] && exit 0

# Allow Claude Code's own internal plans directory (~/.claude/plans/)
[[ "$FILE_PATH" == "$HOME/.claude/plans/"* ]] && exit 0

deny "Plans folder blocked — write plans to $IMPLEMENTATIONS_PATH/<repo>/plans/ instead" \
     "Create the plans file at: $IMPLEMENTATIONS_PATH/<repo>/plans/<name>.md | If the plans/ directory does not exist, create it first. | Blocked path was: $FILE_PATH"
