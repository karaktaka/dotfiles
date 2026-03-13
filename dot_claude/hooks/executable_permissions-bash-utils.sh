#!/usr/bin/env bash
# Permissions gate for standard POSIX / shell utilities.
# Handles commands with dangerous variants first (find, sed, awk, yq),
# then unconditionally allows the remaining safe utilities.

command -v jq &>/dev/null || exit 0

INPUT=$(cat)
[[ "$(jq -r '.tool_name // ""' <<< "$INPUT")" != "Bash" ]] && exit 0

COMMAND=$(jq -r '.tool_input.command // ""' <<< "$INPUT")
CMD_NAME=$(basename "${COMMAND%% *}" 2>/dev/null || echo "${COMMAND%% *}")

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

case "$CMD_NAME" in
  # --- Commands with dangerous variants: deny/ask those first, then allow the rest ---
  find)
    case "$COMMAND" in
      *" -delete"*)          deny "Destructive find — removes matched files" ;;
      *" -exec"*" rm"*)      deny "Destructive find — executes rm on matched files" ;;
    esac
    allow "Safe find" ;;

  sed)
    [[ "$COMMAND" == *" -i"* ]] && ask "In-place sed edit — modifies files directly"
    allow "Safe sed (read-only)" ;;

  awk)
    [[ "$COMMAND" == *" -i"* && "$COMMAND" == *"inplace"* ]] && ask "In-place awk edit — modifies files directly"
    allow "Safe awk (read-only)" ;;

  yq)
    [[ "$COMMAND" == *" -i"* ]] && ask "In-place yq edit — modifies files directly"
    allow "Safe yq (read-only)" ;;

  get-flair.sh)
    allow "Claude flair generator (read-only)" ;;

  # --- Unconditionally safe utilities ---
  # Yield first if a dangerous command appears after a chain operator so that
  # permissions-bash-dangerous.sh can make the call without conflicting.
  basename|cat|column|cut|date|diff|dig|dirname|du|echo|export|file|\
  grep|head|hostname|id|jq|less|ls|md5|more|ping|prettier|pwd|realpath|\
  ruff|shasum|shellcheck|shfmt|sort|stat|tail|tr|uname|uniq|uv|wc|\
  which|whoami)
    case "$COMMAND" in
      *"&& rm "*|*"&& rm"|*"; rm "*|*"; rm") exit 0 ;;
      *"&& curl "*|*"; curl "*)              exit 0 ;;
      *"&& wget "*|*"; wget "*)              exit 0 ;;
    esac
    allow "Safe utility" ;;
esac

exit 0
