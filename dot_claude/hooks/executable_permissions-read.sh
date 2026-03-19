#!/usr/bin/env bash
# Permissions gate for Read, Grep, and Glob tools.
# Deny: .env files. Allow: trusted home-dir paths.

source ~/.claude/hooks/hook-lib.sh || exit 0

case "$TOOL" in
  Read)      FILE="$FILE_PATH" ;;
  Grep|Glob) FILE="$TOOL_INPUT_PATH" ;;
  *)         exit 0 ;;
esac

FILE="${FILE/#\~/$HOME}"  # expand leading ~

# DENY: .env files (Read only — Grep/Glob on a directory is fine)
if [[ "$TOOL" == "Read" ]]; then
  BASE=$(basename "$FILE")
  [[ "$BASE" == ".env" || "$BASE" == .env.* ]] && deny ".env file is protected"
  # DENY: commit-flair.md (deprecated — use get-flair.sh)
  [[ "$BASE" == "commit-flair.md" ]] && deny "commit-flair.md no longer exists. Run ~/.claude/get-flair.sh --dir <repo-path> [--mr] <type> instead. Types: fix, feature, refactor, delete, security, perf, docs, test, deps, config, ui, hotfix, yolo"
fi

# ALLOW: trusted home-dir paths
case "$FILE" in
  "${HOME}/CLAUDE"*|\
  "${HOME}/.claude"*|\
  "${HOME}/.local"*|\
  "${HOME}/.gitconfig"|\
  "${HOME}/personal"*|\
  "${HOME}/workspace"*|\
  /tmp*) allow "Trusted path" ;;
esac

# Work: additional trusted paths
[[ "${CLAUDE_CODE_USE_BEDROCK:-false}" == "true" ]] && case "$FILE" in
  "${HOME}/.aws/config") allow "AWS config (read-only)" ;;
esac

exit 0
