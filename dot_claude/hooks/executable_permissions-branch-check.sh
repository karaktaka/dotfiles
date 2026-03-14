#!/usr/bin/env bash
# Branch safety gate: prevents direct edits on main/master/develop in repos that
# have opted in via a .claude-require-branch marker file at the repo root.
# Encourages feature branch / worktree workflow before making any changes.

command -v jq &>/dev/null || exit 0
command -v git &>/dev/null || exit 0

INPUT=$(cat)
TOOL=$(jq -r '.tool_name // ""' <<< "$INPUT")

# Only check file-editing tools
case "$TOOL" in
  Edit|Write|NotebookEdit) ;;
  *) exit 0 ;;
esac

FILE_PATH=$(jq -r '.tool_input.file_path // ""' <<< "$INPUT")
[[ -z "$FILE_PATH" ]] && exit 0

# Resolve git root from the file's directory
FILE_DIR=$(dirname "$FILE_PATH")
GIT_ROOT=$(git -C "$FILE_DIR" rev-parse --show-toplevel 2>/dev/null)
[[ -z "$GIT_ROOT" ]] && exit 0

# Only enforce in repos that have opted in via marker file
[[ -f "$GIT_ROOT/.claude-require-branch" ]] || exit 0

# Get current branch (empty in detached HEAD)
BRANCH=$(git -C "$GIT_ROOT" branch --show-current 2>/dev/null)

case "$BRANCH" in
  main|master|develop|trunk|"")
    LABEL="${BRANCH:-detached HEAD}"
    REASON="Edits on '${LABEL}' blocked in ${GIT_ROOT} — create a branch or worktree first. Check existing branches: git -C ${GIT_ROOT} branch -v | Then: git -C ${GIT_ROOT} switch -c <name> | Or worktree: git -C ${GIT_ROOT} worktree add .worktrees/<name> -b <name>"
    jq -n --arg r "$REASON" \
      '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":$r}}'
    exit 0
    ;;
esac

exit 0
