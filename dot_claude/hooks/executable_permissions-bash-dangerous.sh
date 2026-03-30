#!/usr/bin/env bash
# Universal safety net for dangerous operations, both direct and chained.
# Catches: rm, curl, wget (direct + chained), git push/checkout (chained).
# This hook runs on EVERY Bash command (no `if` filter) to reliably
# detect dangerous operations hidden anywhere in command chains.

source ~/.claude/hooks/hook-lib.sh || exit 0
[[ "$TOOL" != "Bash" ]] && exit 0

# Direct invocation (command starts with the dangerous tool)
case "$CMD_NAME" in
  rm)   ask "File deletion - confirm path and scope" ;;
  curl) ask "Network request - confirm URL and intent" ;;
  wget) ask "Network download - confirm URL and intent" ;;
esac

# Chained invocation: dangerous tool appears after && or ; in a longer command.
case "$COMMAND" in
  *"&& rm "*|*"&& rm"|*"; rm "*|*"; rm") ask "Chained rm - confirm intent" ;;
  *"&& curl "*|*"; curl "*)              ask "Chained curl - confirm URL" ;;
  *"&& wget "*|*"; wget "*)              ask "Chained wget - confirm URL" ;;
esac

# Chained git push/checkout: regex handles git global flags (-C <path>, -c key=val,
# --no-pager, etc.) between 'git' and the subcommand, which glob patterns miss.
GIT_F='((-[A-Za-z][[:space:]]+[^[:space:]]+|--[a-z][-a-z]*)[[:space:]]+)*'
SEP='(&&|;|\|\|)'
RE_PUSH="${SEP}[[:space:]]*git[[:space:]]+${GIT_F}push([[:space:]]|$)"
RE_DISC="${SEP}[[:space:]]*git[[:space:]]+${GIT_F}checkout[[:space:]]+--[[:space:]]"
[[ "$COMMAND" =~ $RE_PUSH ]] && ask "Chained git push - confirm intent"
[[ "$COMMAND" =~ $RE_DISC ]] && ask "Chained file discard - confirm intent"

exit 0
