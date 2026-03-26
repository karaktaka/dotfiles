#!/usr/bin/env bash
# no-plans-folder.sh: Block writes/mkdir to planning artifact dirs in non-Implementations repos.
# Plans and specs belong in ~/workspace/git/Implementations/<repo>/plans/ — not in per-repo subdirs.

source ~/.claude/hooks/hook-lib.sh || exit 0

IMPLEMENTATIONS_PATH="$HOME/workspace/git/Implementations"

# Matches /plans/ /specs/ /spec/ as a path component, or at end of path
_is_planning_path() {
  [[ "$1" =~ (^|/)(plans|specs?)(\/|$) ]]
}

_is_allowed_path() {
  [[ "$1" == "$IMPLEMENTATIONS_PATH"* ]] || [[ "$1" == "$HOME/.claude/plans/"* ]]
}

case "$TOOL" in
  Edit|Write|NotebookEdit)
    [[ -z "$FILE_PATH" ]] && exit 0
    _is_planning_path "$FILE_PATH" || exit 0
    _is_allowed_path  "$FILE_PATH" && exit 0
    deny "Plans/specs folder blocked — write plans to $IMPLEMENTATIONS_PATH/<repo>/plans/ instead" \
         "Create the plans file at: $IMPLEMENTATIONS_PATH/<repo>/plans/<name>.md | If the plans/ directory does not exist, create it first. | Blocked path was: $FILE_PATH"
    ;;

  Bash)
    [[ "$CMD_NAME" == "mkdir" ]] || exit 0
    _is_planning_path "$COMMAND" || exit 0
    _is_allowed_path  "$COMMAND"  && exit 0
    deny "Plans/specs folder blocked — create directories under $IMPLEMENTATIONS_PATH/<repo>/plans/ instead" \
         "Run: mkdir -p $IMPLEMENTATIONS_PATH/<repo>/plans/ | Blocked command was: $COMMAND"
    ;;
esac
