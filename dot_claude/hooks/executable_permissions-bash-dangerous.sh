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
  *"&& rm "*|*"&& rm"|*"; rm "*|*"; rm")        ask "Chained rm - confirm intent" ;;
  *"&& curl "*|*"; curl "*)                      ask "Chained curl - confirm URL" ;;
  *"&& wget "*|*"; wget "*)                      ask "Chained wget - confirm URL" ;;
  *"&& git push"*|*"; git push"*)                ask "Chained git push - confirm intent" ;;
  *"&& git checkout -- "*|*"; git checkout -- "*) ask "Chained file discard - confirm intent" ;;
esac

exit 0
