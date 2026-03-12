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
  | sed -E 's/(-C|-c)[[:space:]]+\S+[[:space:]]*//' \
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
  *" -- "*)
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

# ALLOW: safe subcommands (stash clear/drop caught above, rest is safe)
case "$STRIPPED" in
  add*|blame*|branch*|commit*|describe*|diff*|fetch*|log*|ls*|pull*|\
  reflog*|remote*|rev-parse*|shortlog*|show*|stash*|status*|switch*|tag*)
    allow "Safe git command" ;;
esac

exit 0
