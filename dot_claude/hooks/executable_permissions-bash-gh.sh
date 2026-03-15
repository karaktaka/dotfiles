#!/usr/bin/env bash
# Permissions gate for the GitHub CLI (gh).
# Safe read operations are allowed; mutations require confirmation.
# Works on all machines (not gated by IS_WORK).

command -v jq &>/dev/null || exit 0

INPUT=$(cat)
[[ "$(jq -r '.tool_name // ""' <<< "$INPUT")" != "Bash" ]] && exit 0

COMMAND=$(jq -r '.tool_input.command // ""' <<< "$INPUT")
CMD_NAME=$(basename "${COMMAND%% *}" 2>/dev/null || echo "${COMMAND%% *}")
[[ "$CMD_NAME" != "gh" ]] && exit 0

allow() {
  jq -n --arg r "$1" \
    '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":$r}}'
  exit 0
}
ask() {
  jq -n --arg r "$1" \
    '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":$r}}'
  exit 0
}

# ── gh api ──────────────────────────────────────────────────────────────────
# Default HTTP method is GET; ask only when an explicit write method is set.
case "$COMMAND" in
  gh*api*)
    case "$COMMAND" in
      *"-X POST"*|*"--method POST"*|\
      *"-X PUT"*|*"--method PUT"*|\
      *"-X PATCH"*|*"--method PATCH"*|\
      *"-X DELETE"*|*"--method DELETE"*)
        ask "gh api write operation — confirm method and endpoint" ;;
    esac
    allow "gh api (read — GET)" ;;
esac

# ── Safe read operations ─────────────────────────────────────────────────────
case "$COMMAND" in
  "gh --version"|\
  "gh auth status"*|\
  gh*pr*list*|gh*pr*view*|gh*pr*diff*|gh*pr*checks*|gh*pr*status*|\
  gh*pr*comment*list*|gh*pr*review*list*|\
  gh*issue*list*|gh*issue*view*|gh*issue*status*|gh*issue*comment*list*|\
  gh*run*list*|gh*run*view*|gh*run*watch*|gh*run*logs*|\
  gh*release*list*|gh*release*view*|\
  gh*workflow*list*|gh*workflow*view*|\
  gh*repo*list*|gh*repo*view*|\
  gh*gist*list*|gh*gist*view*|\
  gh*label*list*|\
  gh*milestone*list*|\
  gh*variable*list*|gh*variable*get*|\
  gh*secret*list*)
    allow "GitHub CLI read-only" ;;
esac

# ── Everything else requires confirmation ────────────────────────────────────
ask "GitHub CLI — may create or modify remote content"
