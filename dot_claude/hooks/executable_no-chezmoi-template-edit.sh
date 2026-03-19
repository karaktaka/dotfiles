#!/usr/bin/env bash
# Block direct edits to chezmoi-managed template targets.
# Template targets are rendered files — edits get overwritten on next `chezmoi apply`.
# Edit the source instead: chezmoi edit <file>

command -v chezmoi &>/dev/null || exit 0

source ~/.claude/hooks/hook-lib.sh || exit 0

case "$TOOL" in
  Edit|Write) ;;
  *) exit 0 ;;
esac

[[ -z "$FILE_PATH" ]] && exit 0

SOURCE_PATH=$(chezmoi source-path "$FILE_PATH" 2>/dev/null)
[[ -z "$SOURCE_PATH" ]] && exit 0
[[ "$SOURCE_PATH" != *.tmpl ]] && exit 0

deny "Chezmoi template target — edits will be overwritten on next apply. Edit the source template instead." \
     "Source template: $SOURCE_PATH | Edit with: chezmoi edit $FILE_PATH | Deploy with: chezmoi apply $FILE_PATH | Never edit the rendered target directly — changes will be lost on next apply."
