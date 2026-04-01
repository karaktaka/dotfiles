#!/usr/bin/env bash
# Permissions gate for the Gitea CLI (tea).
# Safe read operations are allowed; mutations require confirmation.

source ~/.claude/hooks/hook-lib.sh || exit 0
[[ "$TOOL" != "Bash" ]] && exit 0
[[ "$CMD_NAME" != "tea" ]] && exit 0

# Strip 'tea' prefix and common per-command flags that take a value
# so subcommand matching is not fooled by flag values (e.g. --repo owner/api-foo).
# Only the first line is needed — multiline bodies are in subsequent lines.
STRIPPED=$(sed -E \
  -e 's/^tea[[:space:]]*//' \
  -e 's/(--repo|-r)[[:space:]]+[^[:space:]]+[[:space:]]*//g' \
  -e 's/(--remote|-R)[[:space:]]+[^[:space:]]+[[:space:]]*//g' \
  -e 's/(--login|-l)[[:space:]]+[^[:space:]]+[[:space:]]*//g' \
  -e 's/(--output|-o)[[:space:]]+[^[:space:]]+[[:space:]]*//g' \
  -e 's/[[:space:]]+/ /g' \
  -e 's/^ //;s/ $//' \
  <<< "${COMMAND%%$'\n'*}")

# ── tea api ──────────────────────────────────────────────────────────────────
# Default HTTP method is GET; ask when an explicit write method is set OR when
# -F/-f flags are passed (tea promotes the method to POST implicitly).
case "$STRIPPED" in
  "api "*)
    case "$COMMAND" in
      *"-X POST"*|*"--method POST"*|\
      *"-X PUT"*|*"--method PUT"*|\
      *"-X PATCH"*|*"--method PATCH"*|\
      *"-X DELETE"*|*"--method DELETE"*|\
      *" -F "*|*" -F="*|*" -f "*|*" -f="*)
        ask "tea api write operation — confirm method and endpoint" ;;
    esac
    allow "Gitea CLI api (read — GET)" ;;
esac

# ── Safe read operations ─────────────────────────────────────────────────────
case "$STRIPPED" in
  "--version"|\
  "login helper"*|\
  "issues"|"issues "[0-9]*|\
  "issues list"*|"issues ls"*|\
  "issue"|"issue "[0-9]*|\
  "issue list"*|"issue ls"*|\
  "i"|"i "[0-9]*|"i list"*|"i ls"*|\
  "pulls"|"pulls "[0-9]*|\
  "pulls list"*|"pulls ls"*|\
  "pulls checkout"*|\
  "pull"|"pull "[0-9]*|\
  "pull list"*|"pull ls"*|\
  "pull checkout"*|\
  "pr"|"pr "[0-9]*|\
  "pr list"*|"pr ls"*|\
  "pr checkout"*|\
  "labels list"*|"labels ls"*|\
  "label list"*|"label ls"*|\
  "milestones"|"milestones list"*|"milestones ls"*|\
  "milestone"|"milestone list"*|"milestone ls"*|\
  "ms"|"ms list"*|"ms ls"*|\
  "releases"|"releases list"*|"releases ls"*|\
  "release"|"release list"*|"release ls"*|\
  "r list"*|"r ls"*|\
  "repos"|"repos list"*|"repos ls"*|"repos search"*|"repos s"*|\
  "repo"|"repo list"*|"repo ls"*|"repo search"*|"repo s"*|\
  "branches"|"branches list"*|"branches ls"*|\
  "branch"|"branch list"*|"branch ls"*|\
  "b"|"b list"*|"b ls"*|\
  "organizations"|"organizations list"*|"organizations ls"*|\
  "organization"|"organization list"*|"organization ls"*|\
  "org"|"org list"*|"org ls"*|\
  "webhooks list"*|"webhooks ls"*|\
  "webhook list"*|"webhook ls"*|\
  "hooks list"*|"hooks ls"*|\
  "hook list"*|"hook ls"*|\
  "notifications"|"notifications list"*|\
  "notification"|"notification list"*|\
  "n"|"n list"*|\
  "times list"*|"time list"*|"t list"*|\
  "clone"*|"C"*|\
  "whoami"*|\
  "open"*|"o"*|\
  "help"*|"h"*)
    allow "Gitea CLI read-only" ;;
esac

# ── Everything else requires confirmation ────────────────────────────────────
ask "Gitea CLI — may create or modify remote content"
