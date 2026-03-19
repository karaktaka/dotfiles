#!/usr/bin/env bash
# Permissions gate for git commands.
# Deny:    force branch delete, stash clear.
# Rewrite: git checkout → git switch (preferred modern equivalent).
# Ask:     push, checkout -- <file> (file restore), remote config changes, stash drop.
# Allow:   all other git subcommands.

source ~/.claude/hooks/hook-lib.sh || exit 0
[[ "$TOOL" != "Bash" ]] && exit 0
[[ "$CMD_NAME" != "git" ]] && exit 0

# Strip 'git' prefix, flags that take a value (-C path, -c key=val),
# and standalone global boolean flags (--no-pager, --no-optional-locks, etc.)
# to isolate the actual subcommand + its args. This prevents commit message
# content or branch names from accidentally matching deny/ask patterns.
STRIPPED=$(sed -E \
  -e 's/^git[[:space:]]*//' \
  -e 's/(-C|-c)[[:space:]]+[^[:space:]]+[[:space:]]*//' \
  -e 's/--(no-pager|no-optional-locks|paginate|bare|no-replace-objects|literal-pathspecs|glob-pathspecs|noglob-pathspecs|icase-pathspecs)[[:space:]]*//' \
  <<< "$COMMAND" | xargs 2>/dev/null || echo "$COMMAND")

# DENY (match against STRIPPED subcommand to avoid false positives from message bodies)
case "$STRIPPED" in
  branch*\ -D\ *|branch*\ -D) deny "Force branch deletion — use 'git branch -d' for merged branches" "Use 'git branch -d <branch>' (safe delete, requires merged). To inspect unique commits: git log <branch> --not --remotes. Ask the user before force-deleting." ;;
  stash\ clear*)               deny "Destructive stash clear — all stash entries would be lost" "Use 'git stash drop stash@{N}' to remove individual entries. List stashes first: git stash list. Never clear all stashes without explicit user instruction." ;;
esac

# REWRITE: git checkout → git switch / git restore
# git checkout -b <branch>  →  git switch -c <branch>
case "$COMMAND" in
  git*checkout*-b*)
    new_cmd=$(perl -pe 's/\bcheckout\b\s*-b/switch -c/' <<< "$COMMAND")
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
    new_cmd=$(perl -pe 's/\bcheckout\b/switch/' <<< "$COMMAND")
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
    if echo "$COMMAND" | grep -Eqi "Claude[[:space:]]+[A-Za-z][^<]*<noreply@anthropic\.com"; then
      deny "Claude model name as co-author — run ~/.claude/get-flair.sh --dir <repo-path> <type> instead" "Run: ~/.claude/get-flair.sh --dir <repo-path> <type> | Types: fix, feature, refactor, delete, security, perf, docs, test, deps, config, ui, hotfix, yolo | Use the output as the sole Co-Authored-By line. Never include both flair and the default Claude co-author."
    fi
    REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
    if [[ "$REMOTE" == *"gitlab.example.com"* ]] && echo "$COMMAND" | grep -qi "noreply@anthropic\.com"; then
      deny "KN repo: use ~/.claude/get-flair.sh --dir <repo-path> <type> for a character co-author" "KN GitLab repos require a character flair co-author. Run: ~/.claude/get-flair.sh --dir <repo-path> <type> | Replace the noreply@anthropic.com line with the flair output."
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
