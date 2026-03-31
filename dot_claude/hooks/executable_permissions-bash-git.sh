#!/usr/bin/env bash
# Permissions gate for git commands (only fires when `if: "Bash(git *)"` matches).
# Deny:    force branch delete, stash clear, wrong co-author format.
# Rewrite: git checkout → git switch (preferred modern equivalent).
# Ask:     push, checkout -- <file> (file restore), remote config changes, stash drop.
# Allow:   all other git subcommands.
# Chain safety handled by permissions-bash-dangerous.sh (runs on every command).

source ~/.claude/hooks/hook-lib.sh || exit 0
[[ "$TOOL" != "Bash" ]] && exit 0
[[ "$CMD_NAME" != "git" ]] && exit 0

# Strip 'git' prefix, flags that take a value (-C path, -c key=val),
# and standalone global boolean flags (--no-pager, --no-optional-locks, etc.)
# to isolate the actual subcommand + its args. This prevents commit message
# content or branch names from accidentally matching deny/ask patterns.
STRIPPED=$(sed -E \
  -e 's/^git[[:space:]]*//' \
  -e 's/(-C|-c)[[:space:]]+[^[:space:]]+[[:space:]]*//g' \
  -e 's/--(no-pager|no-optional-locks|paginate|bare|no-replace-objects|literal-pathspecs|glob-pathspecs|noglob-pathspecs|icase-pathspecs)[[:space:]]*//g' \
  -e 's/[[:space:]]+/ /g' \
  -e 's/^ //;s/ $//' \
  <<< "${COMMAND%%$'\n'*}")

# DENY (match against STRIPPED subcommand to avoid false positives from message bodies)
case "$STRIPPED" in
  branch*\ -D\ *|branch*\ -D) deny "Force branch deletion — use 'git branch -d' for merged branches" "Use 'git branch -d <branch>' (safe delete, requires merged). To inspect unique commits: git log <branch> --not --remotes. Ask the user before force-deleting." ;;
  stash\ clear*)               deny "Destructive stash clear — all stash entries would be lost" "Use 'git stash drop stash@{N}' to remove individual entries. List stashes first: git stash list. Never clear all stashes without explicit user instruction." ;;
esac

# REWRITE: git checkout → git switch / git restore
# Match against STRIPPED (not $COMMAND) so commit messages or file paths
# containing "checkout" don't accidentally trigger these rewrites.
case "$STRIPPED" in
  checkout" -b"*)
    new_cmd=$(perl -pe 's/\bcheckout\b\s*-b/switch -c/' <<< "$COMMAND")
    rewrite_and_allow "$new_cmd" "Rewritten: use 'git switch -c' instead of 'git checkout -b'"
    ;;
  checkout*" -- "*)
    ask "Discards file changes — use 'git restore <file>' instead of 'git checkout -- <file>'"
    ;;
  checkout*)
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

# COMMIT: reject wrong co-author formats before allowing
# Catches model-name variants (e.g. "Claude Sonnet 4.6") on all repos,
# and plain Claude attribution on non-GitHub repos where a character flair is required.
case "$STRIPPED" in
  commit*)
    if echo "$COMMAND" | grep -Eqi "Claude[[:space:]]+[A-Za-z][^<]*<noreply@anthropic\.com"; then
      deny "Claude model name as co-author — run ~/.claude/get-flair.sh --dir <repo-path> <type> instead" "Run: ~/.claude/get-flair.sh --dir <repo-path> <type> | Types: fix, feature, refactor, delete, security, perf, docs, test, deps, config, ui, hotfix, yolo | Use the output as the sole Co-Authored-By line. Never include both flair and the default Claude co-author."
    fi
    REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
    if [[ "$REMOTE" != *"github.com"* ]] && [[ -n "$REMOTE" ]] && echo "$COMMAND" | grep -qi "noreply@anthropic\.com"; then
      deny "Non-GitHub repo: use ~/.claude/get-flair.sh --dir <repo-path> <type> for a character co-author" "Non-GitHub repos require a character flair co-author. Run: ~/.claude/get-flair.sh --dir <repo-path> <type> | Replace the noreply@anthropic.com line with the flair output."
    fi
    ;;
esac

# PLANS/SPECS: warn when staging planning artifacts (should stay local until implemented)
case "$STRIPPED" in
  add*)
    if echo "$COMMAND" | grep -Eq '(^|/)(plans|specs?)(\/|$)'; then
      if ! echo "$COMMAND" | grep -q "Implementations"; then
        ask "Staging planning artifacts - plans/specs should stay local until the feature is implemented"
      fi
    fi
    ;;
esac

# ALLOW: safe subcommands (stash clear/drop caught above, rest is safe)
case "$STRIPPED" in
  add*|annotate*|bisect*|blame*|branch*|cat-file*|check-attr*|check-ignore*|\
  check-mailmap*|cherry*|commit*|count-objects*|describe*|diff*|fetch*|\
  for-each-ref*|format-patch*|fsck*|gc*|grep*|log*|ls*|merge-base*|name-rev*|\
  notes*|pack-refs*|pull*|range-diff*|reflog*|remote*|rerere*|rev-list*|\
  rev-parse*|revert*|shortlog*|show*|sparse-checkout*|stash*|status*|submodule*|\
  switch*|tag*|var*|verify-commit*|verify-pack*|verify-tag*|version*|\
  whatchanged*|worktree*)
    allow "Safe git command" ;;
esac

exit 0
