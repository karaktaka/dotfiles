#!/usr/bin/env bash
# Branch safety gate: prevents direct edits on main/master/develop in repos that
# have opted in via a .claude-require-branch marker file at the repo root.
# Encourages feature branch / worktree workflow before making any changes.

command -v git &>/dev/null || exit 0

source ~/.claude/hooks/hook-lib.sh || exit 0

# Only check file-editing tools
case "$TOOL" in
  Edit|Write|NotebookEdit) ;;
  *) exit 0 ;;
esac

[[ -z "$FILE_PATH" ]] && exit 0

# Resolve git root from the file's directory
FILE_DIR=$(dirname "$FILE_PATH")
GIT_ROOT=$(git -C "$FILE_DIR" rev-parse --show-toplevel 2>/dev/null)
[[ -z "$GIT_ROOT" ]] && exit 0

# Only enforce in repos that have opted in via marker file
[[ -f "$GIT_ROOT/.claude-require-branch" ]] || exit 0

# Allow edits during in-progress git operations (rebase, cherry-pick, merge)
# These put git in detached HEAD state but legitimately require file edits for conflict resolution
GIT_DIR=$(git -C "$GIT_ROOT" rev-parse --git-dir 2>/dev/null)
if [[ -n "$GIT_DIR" ]]; then
  for marker in REBASE_HEAD CHERRY_PICK_HEAD MERGE_HEAD BISECT_HEAD; do
    [[ -f "$GIT_DIR/$marker" ]] && exit 0
  done
  [[ -d "$GIT_DIR/rebase-merge" ]] && exit 0
  [[ -d "$GIT_DIR/rebase-apply" ]] && exit 0
fi

# Get current branch (empty in detached HEAD)
BRANCH=$(git -C "$GIT_ROOT" branch --show-current 2>/dev/null)

case "$BRANCH" in
  main|master|develop|trunk|"")
    LABEL="${BRANCH:-detached HEAD}"
    deny "Edits on '${LABEL}' blocked in ${GIT_ROOT} — create a worktree or branch first" \
         "PREFERRED (worktree): git -C ${GIT_ROOT} worktree add .worktrees/<name> -b <name> — then work inside .worktrees/<name>/. Worktrees keep work isolated without stashing or switching context. | ALTERNATIVE (quick single-file fix only): git -C ${GIT_ROOT} switch -c <name>. | Check existing branches first: git -C ${GIT_ROOT} branch -v. | Do NOT commit directly to ${LABEL}."
    ;;
esac

exit 0
