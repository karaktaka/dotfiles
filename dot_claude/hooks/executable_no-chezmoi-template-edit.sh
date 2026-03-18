#!/usr/bin/env bash
# Block direct edits to chezmoi-managed template targets.
# Template targets are rendered files — edits get overwritten on next `chezmoi apply`.
# Edit the source instead: chezmoi edit <file>

command -v jq &>/dev/null || exit 0
command -v chezmoi &>/dev/null || exit 0

INPUT=$(cat)
TOOL=$(jq -r '.tool_name // ""' <<< "$INPUT")

case "$TOOL" in
  Edit|Write) ;;
  *) exit 0 ;;
esac

FILE_PATH=$(jq -r '.tool_input.file_path // ""' <<< "$INPUT")
[[ -z "$FILE_PATH" ]] && exit 0

SOURCE_PATH=$(chezmoi source-path "$FILE_PATH" 2>/dev/null)
[[ -z "$SOURCE_PATH" ]] && exit 0
[[ "$SOURCE_PATH" != *.tmpl ]] && exit 0

jq -n --arg fp "$FILE_PATH" --arg sp "$SOURCE_PATH" \
  '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":("Chezmoi template target — edits will be overwritten on next apply. Edit the source instead: chezmoi edit " + $fp + " (source: " + $sp + ")")}}'
exit 0
