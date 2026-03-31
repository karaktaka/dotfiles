#!/usr/bin/env bash
# worktree-setup.sh: Creates a git worktree and installs project deps.
# Fires on WorktreeCreate event — replaces default git worktree behavior.
# Must print the worktree path on stdout; failure or empty output aborts creation.

INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty')
NAME=$(echo "$INPUT" | jq -r '.name // empty')

[[ -z "$CWD" || -z "$NAME" || ! -d "$CWD" ]] && exit 1

WORKTREE_PATH="$CWD/.claude/worktrees/$NAME"

mkdir -p "$CWD/.claude/worktrees"

# Create worktree on a new branch; fall back to checking out an existing branch.
if ! git -C "$CWD" worktree add "$WORKTREE_PATH" -b "$NAME" &>/dev/null; then
  git -C "$CWD" worktree add "$WORKTREE_PATH" "$NAME" &>/dev/null || exit 1
fi

# Node.js: symlink is handled by worktree.symlinkDirectories setting,
# but if node_modules doesn't exist (no main checkout deps), install them.
if [[ -f "$WORKTREE_PATH/package.json" ]] && [[ ! -d "$WORKTREE_PATH/node_modules" ]]; then
  (cd "$WORKTREE_PATH" && npm install --no-audit --no-fund) >/dev/null 2>&1 &
fi

# Python: if .venv doesn't exist (not symlinked), sync deps.
if [[ -f "$WORKTREE_PATH/pyproject.toml" ]] && [[ ! -d "$WORKTREE_PATH/.venv" ]]; then
  (cd "$WORKTREE_PATH" && uv sync) >/dev/null 2>&1 &
fi

# Pre-commit hooks: install if config exists.
if [[ -f "$WORKTREE_PATH/.pre-commit-config.yaml" ]] && command -v pre-commit >/dev/null 2>&1; then
  (cd "$WORKTREE_PATH" && pre-commit install) >/dev/null 2>&1 &
fi

echo "$WORKTREE_PATH"
