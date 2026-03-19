#!/usr/bin/env bash
# Permissions gate for explicitly dangerous shell operations: rm, curl, wget.
# All require explicit user confirmation.

source ~/.claude/hooks/hook-lib.sh || exit 0
[[ "$TOOL" != "Bash" ]] && exit 0

# Direct invocation (command starts with the dangerous tool)
case "$CMD_NAME" in
  rm)   ask "File deletion — confirm path and scope" ;;
  curl) ask "Network request — confirm URL and intent" ;;
  wget) ask "Network download — confirm URL and intent" ;;
esac

# Chained invocation: dangerous tool appears after && or ; in a longer command.
# Other allow-hooks yield (exit 0) when they detect this pattern, so this hook
# is the sole decision-maker for the chain.
case "$COMMAND" in
  *"&& rm "*|*"&& rm"|*"; rm "*|*"; rm") ask "Chained command contains 'rm' — confirm intent" ;;
  *"&& curl "*|*"; curl "*)              ask "Chained command contains 'curl' — confirm URL" ;;
  *"&& wget "*|*"; wget "*)              ask "Chained command contains 'wget' — confirm URL" ;;
esac

exit 0
