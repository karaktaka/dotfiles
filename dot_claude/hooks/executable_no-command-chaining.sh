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

source ~/.claude/hooks/hook-lib.sh || exit 0
[[ "$TOOL" != "Bash" ]] && exit 0

# Detect && chaining in two forms:
#   1. Same-line:        cmd1 && cmd2       (first line only — avoids heredoc body false positives)
#   2. Continuation:     cmd1 \             (a later line starts with optional whitespace then &&)
#                          && cmd2
FIRST_LINE="${COMMAND%%$'\n'*}"

# Allow && when the leading command is a shell-state-modifier.
# Covers both bare form (cd /x && cmd) and subshell form ((cd /x && cmd)).
# Also covers bare variable assignments (VAR=$(cmd) && cmd2) — same-shell
# state setup, functionally equivalent to export for the chained command.
STATE_MODIFIER_RE='^[[:space:]]*\(?(cd|pushd|export|source|\.|mkdir|eval|unset)[[:space:]]|^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*='
if [[ "$FIRST_LINE" =~ $STATE_MODIFIER_RE ]]; then
  # cd && <tool-with-C-flag> is denied — use the tool's native -C flag instead.
  if [[ "$FIRST_LINE" =~ ^[[:space:]]*\(?[[:space:]]*cd[[:space:]] ]]; then
    AFTER_CMD=$(sed 's/.*&&[[:space:]]*//' <<< "$FIRST_LINE" | awk '{print $1}')
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

# Only scan continuation lines when the command actually spans multiple lines.
CONTINUATION=""
[[ "$FIRST_LINE" != "$COMMAND" ]] && CONTINUATION=$(printf '%s\n' "$COMMAND" | tail -n +2 | grep -E '^\s*&&')

if [[ "$FIRST_LINE" == *" && "* ]] || [ -n "$CONTINUATION" ]; then
  deny "Command chaining with && is not allowed. Use separate Bash tool calls — each command gets its own call. Pipes (|) and fallback (||) are fine. Exception: leading state-modifiers (cd, pushd, export, source, mkdir, eval, unset), subshell (cd ...), and bare variable assignments (VAR=...) may use &&." \
       "This command did NOT execute — the entire Bash call was blocked before the shell ran it. Do not infer system state (file existence, command success, etc.) from this denial. Split the command into separate Bash tool calls to get actual results."
fi

exit 0
