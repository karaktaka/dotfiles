#!/usr/bin/env bash
# Enforce no-command-chaining policy.
# Rejects Bash commands that use && to chain multiple commands.
# Use separate Bash tool calls instead — they're clearer and individually reviewable.
#
# Exception: && is allowed when the leading command is a shell-state-modifier —
# i.e. a command that changes directory, environment, or sets up prerequisites
# that subsequent commands genuinely depend on.
# Note: prefer tool-native dir flags where they exist (git -C, go -C, uv --directory)
# over cd &&. Use cd && only for tools that truly have no directory flag (e.g. glab).
# Allowed leading patterns:
#   - cd, pushd, export, source, ., mkdir, eval, unset  (explicit state modifiers)
#   - (cd ...) / (pushd ...)  subshell form, e.g. (cd worktree && glab ...)
#   - VAR=...  bare variable assignment (functionally equivalent to export for same-shell use)
#
# Exception to the exception: cd && <tool> is DENIED when <tool> supports a native
# -C <dir> flag (git, go, make, ninja). Use the flag instead.

command -v jq &>/dev/null || exit 0

INPUT=$(cat)
[[ "$(jq -r '.tool_name // ""' <<< "$INPUT")" != "Bash" ]] && exit 0

COMMAND=$(jq -r '.tool_input.command // ""' <<< "$INPUT")

deny() {
  jq -n --arg r "$1" \
    '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":$r}}'
  exit 0
}

# Detect && chaining in two forms:
#   1. Same-line:        cmd1 && cmd2       (first line only — avoids heredoc body false positives)
#   2. Continuation:     cmd1 \             (a later line starts with optional whitespace then &&)
#                          && cmd2
FIRST_LINE=$(printf '%s\n' "$COMMAND" | head -1)
CONTINUATION=$(printf '%s\n' "$COMMAND" | tail -n +2 | grep -E '^\s*&&')

# Allow && when the leading command is a shell-state-modifier.
# Covers both bare form (cd /x && cmd) and subshell form ((cd /x && cmd)).
# Also covers bare variable assignments (VAR=$(cmd) && cmd2) — same-shell
# state setup, functionally equivalent to export for the chained command.
STATE_MODIFIER_RE='^\s*\(?(cd|pushd|export|source|\.|mkdir|eval|unset)\s|^\s*[A-Za-z_][A-Za-z0-9_]*='
if printf '%s\n' "$FIRST_LINE" | grep -qE "$STATE_MODIFIER_RE"; then
  # cd && <tool-with-C-flag> is denied — use the tool's native -C flag instead.
  if printf '%s\n' "$FIRST_LINE" | grep -qE '^\s*\(?\s*cd\s'; then
    AFTER_CMD=$(printf '%s\n' "$FIRST_LINE" | sed 's/.*&&[[:space:]]*//' | awk '{print $1}')
    AFTER_CMD_BASE=$(basename "$AFTER_CMD" 2>/dev/null)
    case "$AFTER_CMD_BASE" in
      git)    deny "Use 'git -C <path> <subcommand>' instead of 'cd <path> && git'" ;;
      go)     deny "Use 'go -C <path> <subcommand>' instead of 'cd <path> && go' (note: -C must be go's first flag)" ;;
      make)   deny "Use 'make -C <dir>' instead of 'cd <dir> && make'" ;;
      ninja)  deny "Use 'ninja -C <dir>' instead of 'cd <dir> && ninja'" ;;
      uv)     deny "Use 'uv --directory <path> <subcommand>' (or --project) instead of 'cd <path> && uv'" ;;
      npm)    deny "Use 'npm --prefix <path> <subcommand>' instead of 'cd <path> && npm'" ;;
      yarn)   deny "Use 'yarn --cwd <path> <subcommand>' instead of 'cd <path> && yarn'" ;;
      pnpm)   deny "Use 'pnpm --dir <path> <subcommand>' instead of 'cd <path> && pnpm'" ;;
      poetry) deny "Use 'poetry --directory <path> <subcommand>' instead of 'cd <path> && poetry'" ;;
    esac
  fi
  exit 0
fi

if printf '%s\n' "$FIRST_LINE" | grep -qF ' && ' || [ -n "$CONTINUATION" ]; then
  jq -n --arg r "Command chaining with && is not allowed. Use separate Bash tool calls — each command gets its own call. Pipes (|) and fallback (||) are fine. Exception: leading state-modifiers (cd, pushd, export, source, mkdir, eval, unset), subshell (cd ...), and bare variable assignments (VAR=...) may use &&." \
    '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":$r}}'
  exit 0
fi

exit 0
