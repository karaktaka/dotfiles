#!/usr/bin/env bash
# Permissions gate for the Codeberg/Forgejo CLI (berg).
# Safe read operations are allowed; mutations require confirmation.

source ~/.claude/hooks/hook-lib.sh || exit 0
[[ "$TOOL" != "Bash" ]] && exit 0
[[ "$CMD_NAME" != "berg" ]] && exit 0

# Strip 'berg' prefix and common global flags that take a value
# so subcommand matching is not fooled by flag values.
# Only the first line is needed — multiline bodies are in subsequent lines.
STRIPPED=$(sed -E \
  -e 's/^berg[[:space:]]*//' \
  -e 's/(--output-mode)[[:space:]]+[^[:space:]]+[[:space:]]*//g' \
  -e 's/(--max-width|-w)[[:space:]]+[^[:space:]]+[[:space:]]*//g' \
  -e 's/--non-interactive[[:space:]]*//g' \
  -e 's/[[:space:]]+/ /g' \
  -e 's/^ //;s/ $//' \
  <<< "${COMMAND%%$'\n'*}")

# ── berg api ─────────────────────────────────────────────────────────────────
# berg api only exposes a 'version' subcommand (no generic HTTP caller).
case "$STRIPPED" in
  "api version"*)
    allow "Codeberg/Forgejo CLI api (read — version)" ;;
  "api"*)
    ask "Codeberg/Forgejo CLI api operation — confirm intent" ;;
esac

# ── Safe read operations ─────────────────────────────────────────────────────
case "$STRIPPED" in
  "--version"|\
  "help"*|\
  "auth list"*|\
  "issue list"*|"issue view"*|\
  "pull list"*|"pull view"*|\
  "label list"*|\
  "release list"*|\
  "repo info"*|"repo branch list"*|\
  "milestone list"*|"milestone view"*|\
  "notification list"*|"notification view"*|\
  "keys list"*|"keys ssh list"*|"keys gpg list"*|\
  "user info"*|"user"*|\
  "config show"*|"config info"*|\
  "completion"*)
    allow "Codeberg/Forgejo CLI read-only" ;;
esac

# ── Everything else requires confirmation ────────────────────────────────────
ask "Codeberg/Forgejo CLI — may create or modify remote content"
