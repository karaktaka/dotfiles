#!/usr/bin/env bash
# worktree-setup.sh: Auto-install dependencies when a worktree is created.
# Fires on WorktreeCreate event. Detects project type and runs the appropriate installer.

# WorktreeCreate provides worktree path via hook input
INPUT=$(cat)
WORKTREE_PATH=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('worktree_path',''))" 2>/dev/null)
[[ -z "$WORKTREE_PATH" ]] && exit 0
[[ ! -d "$WORKTREE_PATH" ]] && exit 0

# Node.js: symlink is handled by worktree.symlinkDirectories setting,
# but if node_modules doesn't exist (no main checkout deps), install them.
if [[ -f "$WORKTREE_PATH/package.json" ]] && [[ ! -d "$WORKTREE_PATH/node_modules" ]]; then
  (cd "$WORKTREE_PATH" && npm install --no-audit --no-fund) >/dev/null 2>&1 &
fi

# Python: if .venv doesn't exist (not symlinked), sync deps
if [[ -f "$WORKTREE_PATH/pyproject.toml" ]] && [[ ! -d "$WORKTREE_PATH/.venv" ]]; then
  (cd "$WORKTREE_PATH" && uv sync) >/dev/null 2>&1 &
fi

# Pre-commit hooks: install if config exists
if [[ -f "$WORKTREE_PATH/.pre-commit-config.yaml" ]] && command -v pre-commit >/dev/null 2>&1; then
  (cd "$WORKTREE_PATH" && pre-commit install) >/dev/null 2>&1 &
fi

echo "$WORKTREE_PATH"
exit 0
