#!/usr/bin/env bash
# Permissions gate for git commands.
# Deny:    force branch delete, stash clear.
# Rewrite: git checkout → git switch (preferred modern equivalent).
# Ask:     push, checkout -- <file> (file restore), remote config changes, stash drop.
# Allow:   all other git subcommands.

command -v jq &>/dev/null || exit 0

INPUT=$(cat)
[[ "$(jq -r '.tool_name // ""' <<< "$INPUT")" != "Bash" ]] && exit 0

COMMAND=$(jq -r '.tool_input.command // ""' <<< "$INPUT")
CMD_NAME=$(basename "${COMMAND%% *}" 2>/dev/null || echo "${COMMAND%% *}")
[[ "$CMD_NAME" != "git" ]] && exit 0

# Strip 'git' prefix and flags that take a value (-C path, -c key=val)
# to isolate the actual subcommand + its args. This prevents commit message
# content or branch names from accidentally matching deny/ask patterns.
STRIPPED=$(echo "$COMMAND" \
  | sed -E 's/^git[[:space:]]*//' \
  | sed -E 's/(-C|-c)[[:space:]]+[^[:space:]]+[[:space:]]*//' \
  | xargs 2>/dev/null || echo "$COMMAND")

allow() {
  jq -n --arg r "$1" \
    '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":$r}}'
  exit 0
}
deny() {
  jq -n --arg r "$1" \
    '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":$r}}'
  exit 0
}
ask() {
  jq -n --arg r "$1" \
    '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":$r}}'
  exit 0
}
rewrite_and_allow() {
  local new_cmd="$1" reason="$2"
  local updated_input
  updated_input=$(jq --arg cmd "$new_cmd" '.tool_input | .command = $cmd' <<< "$INPUT")
  jq -n --arg r "$reason" --argjson ui "$updated_input" \
    '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":$r,"updatedInput":$ui}}'
  exit 0
}

# DENY (match against STRIPPED subcommand to avoid false positives from message bodies)
case "$STRIPPED" in
  branch*\ -D\ *|branch*\ -D) deny "Force branch deletion — use 'git branch -d' for merged branches" ;;
  stash\ clear*)               deny "Destructive stash clear — all stash entries would be lost" ;;
esac

# REWRITE: git checkout → git switch / git restore
# git checkout -b <branch>  →  git switch -c <branch>
case "$COMMAND" in
  git*checkout*-b*)
    new_cmd=$(sed 's/checkout[[:space:]]*-b/switch -c/' <<< "$COMMAND")
    rewrite_and_allow "$new_cmd" "Rewritten: use 'git switch -c' instead of 'git checkout -b'"
    ;;
esac
# git checkout -- <file>  →  ask, hint to use git restore
case "$COMMAND" in
  *checkout*" -- "*)
    ask "Discards file changes — use 'git restore <file>' instead of 'git checkout -- <file>'"
    ;;
esac
# git checkout <branch>  →  git switch <branch>
case "$COMMAND" in
  git*checkout*)
    new_cmd=$(sed 's/\bcheckout\b/switch/' <<< "$COMMAND")
    rewrite_and_allow "$new_cmd" "Rewritten: use 'git switch' instead of 'git checkout'"
    ;;
esac

# ASK (STRIPPED for subcommand-specific patterns; COMMAND for positional ones like --)
case "$STRIPPED" in
  push*)
    ask "Remote push" ;;
  remote\ add\ *|remote\ remove\ *|remote\ rename\ *|remote\ set-url\ *)
    ask "Remote config change" ;;
  stash\ drop*)
    ask "Stash drop" ;;
esac

# Also check the last segment of a && / ; chain for ask-worthy operations.
# String-pattern matching on "&&" is unreliable when && is followed by a
# line-continuation backslash + newline, so we extract the last segment
# by stripping everything up to the last && or ; instead.
if [[ "$COMMAND" == *"&&"* || "$COMMAND" == *";"* ]]; then
  _last="${COMMAND##*&&}"
  # If ; produces a later segment, prefer that
  [[ "${COMMAND##*;}" != "$COMMAND" && "${#COMMAND##*;}" -lt "${#_last}" ]] && _last="${COMMAND##*;}"
  # Strip leading whitespace and backslash continuations, then normalise
  _last_trimmed=$(printf '%s' "$_last" | sed -E 's/^[[:space:]\\]*//' | xargs 2>/dev/null || printf '%s' "$_last")
  _last_name=$(basename "${_last_trimmed%% *}" 2>/dev/null)
  if [[ "$_last_name" == "git" ]]; then
    _last_stripped=$(printf '%s' "$_last_trimmed" \
      | sed -E 's/^git[[:space:]]*//' \
      | sed -E 's/(-C|-c)[[:space:]]+[^[:space:]]+[[:space:]]*//' \
      | xargs 2>/dev/null || echo "")
    case "$_last_stripped" in
      push*)     ask "Chained git push — confirm intent" ;;
      checkout*) ask "Chained git checkout — confirm intent" ;;
    esac
  fi
fi

# COMMIT: reject wrong co-author formats before allowing
# Catches model-name variants (e.g. "Claude Sonnet 4.6") on all repos,
# and plain Claude attribution on KN GitLab repos where a character is required.
case "$STRIPPED" in
  commit*)
    if echo "$COMMAND" | grep -Eqi "Claude[[:space:]]+[A-Za-z][^<]*noreply@anthropic\.com"; then
      deny "Claude model name as co-author — run ~/.claude/get-flair.sh <type> instead"
    fi
    REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
    if [[ "$REMOTE" == *"gitlab.example.com"* ]] && echo "$COMMAND" | grep -qi "noreply@anthropic\.com"; then
      deny "KN repo: use ~/.claude/get-flair.sh <type> for a character co-author"
    fi
    ;;
esac

# ALLOW: safe subcommands (stash clear/drop caught above, rest is safe)
# Yield if a dangerous command appears after a chain operator — let
# permissions-bash-dangerous.sh make the call so we don't conflict with it.
case "$COMMAND" in
  *"&& rm "*|*"&& rm"|*"; rm "*|*"; rm") exit 0 ;;
  *"&& curl "*|*"; curl "*)              exit 0 ;;
  *"&& wget "*|*"; wget "*)              exit 0 ;;
esac
case "$STRIPPED" in
  add*|blame*|branch*|check-ignore*|commit*|describe*|diff*|fetch*|log*|ls*|pull*|\
  reflog*|remote*|rev-parse*|shortlog*|show*|stash*|status*|switch*|tag*|worktree*)
    allow "Safe git command" ;;
esac

exit 0
