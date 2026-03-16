#!/usr/bin/env bash
# Enforce no-command-chaining policy.
# Rejects Bash commands that use && to chain multiple commands.
# Use separate Bash tool calls instead — they're clearer and individually reviewable.
#
# Exception: && is allowed when the leading command is a shell-state-modifier —
# i.e. a command that changes directory, environment, or sets up prerequisites
# that subsequent commands genuinely depend on. These have no --directory/--env
# flag equivalent and cannot be moved to a separate tool call.
# Allowed leading commands: cd, pushd, export, source, ., mkdir, eval, unset

command -v jq &>/dev/null || exit 0

INPUT=$(cat)
[[ "$(jq -r '.tool_name // ""' <<< "$INPUT")" != "Bash" ]] && exit 0

COMMAND=$(jq -r '.tool_input.command // ""' <<< "$INPUT")

# Detect && chaining in two forms:
#   1. Same-line:        cmd1 && cmd2       (first line only — avoids heredoc body false positives)
#   2. Continuation:     cmd1 \             (a later line starts with optional whitespace then &&)
#                          && cmd2
FIRST_LINE=$(printf '%s\n' "$COMMAND" | head -1)
CONTINUATION=$(printf '%s\n' "$COMMAND" | tail -n +2 | grep -E '^\s*&&')

# Allow && when the leading command is a shell-state-modifier
STATE_MODIFIER_RE='^\s*(cd|pushd|export|source|\.|mkdir|eval|unset)\s'
if printf '%s\n' "$FIRST_LINE" | grep -qE "$STATE_MODIFIER_RE"; then
  exit 0
fi

if printf '%s\n' "$FIRST_LINE" | grep -qF ' && ' || [ -n "$CONTINUATION" ]; then
  jq -n --arg r "Command chaining with && is not allowed. Use separate Bash tool calls — each command gets its own call. Pipes (|) and fallback (||) are fine. Exception: leading state-modifiers (cd, pushd, export, source, mkdir, eval, unset) may use &&." \
    '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":$r}}'
  exit 0
fi

exit 0
