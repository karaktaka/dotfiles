#!/usr/bin/env bash
# Permissions gate for the GitHub CLI (gh).
# Safe read operations are allowed; mutations require confirmation.
# Works on all machines (not gated by IS_WORK).

source ~/.claude/hooks/hook-lib.sh || exit 0
[[ "$TOOL" != "Bash" ]] && exit 0
[[ "$CMD_NAME" != "gh" ]] && exit 0

# Strip 'gh' prefix and global flags that take a value (--repo/-R, --hostname)
# so subcommand matching is not fooled by flag values (e.g. --repo owner/api-foo
# or --body "...views.py..."). Only the first line is needed — multiline bodies
# are in subsequent lines and never affect the subcommand.
STRIPPED=$(sed -E \
  -e 's/^gh[[:space:]]*//' \
  -e 's/(--repo|-R)[[:space:]]+[^[:space:]]+[[:space:]]*//g' \
  -e 's/--hostname[[:space:]]+[^[:space:]]+[[:space:]]*//g' \
  -e 's/[[:space:]]+/ /g' \
  -e 's/^ //;s/ $//' \
  <<< "${COMMAND%%$'\n'*}")

# ── gh api ──────────────────────────────────────────────────────────────────
# Default HTTP method is GET; ask when an explicit write method is set OR when
# -F/-f/--field/--raw-field are passed (gh promotes the method to POST implicitly).
case "$STRIPPED" in
  "api "*)
    case "$COMMAND" in
      *"-X POST"*|*"--method POST"*|\
      *"-X PUT"*|*"--method PUT"*|\
      *"-X PATCH"*|*"--method PATCH"*|\
      *"-X DELETE"*|*"--method DELETE"*|\
      *" -F "*|*" -F="*|*" -f "*|*" -f="*|\
      *" --field "*|*" --field="*|\
      *" --raw-field "*|*" --raw-field="*)
        ask "gh api write operation — confirm method and endpoint" ;;
    esac
    allow "gh api (read — GET)" ;;
esac

# ── Safe read operations ─────────────────────────────────────────────────────
case "$STRIPPED" in
  "--version"|\
  "auth status"*|\
  "pr list"*|"pr view"*|"pr diff"*|"pr checks"*|"pr status"*|\
  "pr comment list"*|"pr review list"*|"pr review view"*|\
  "issue list"*|"issue view"*|"issue status"*|"issue comment list"*|\
  "run list"*|"run view"*|"run watch"*|"run logs"*|\
  "release list"*|"release view"*|\
  "workflow list"*|"workflow view"*|\
  "repo list"*|"repo view"*|\
  "gist list"*|"gist view"*|\
  "label list"*|\
  "milestone list"*|\
  "variable list"*|"variable get"*|\
  "secret list"*)
    allow "GitHub CLI read-only" ;;
esac

# ── Everything else requires confirmation ────────────────────────────────────
ask "GitHub CLI — may create or modify remote content"
