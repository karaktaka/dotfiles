#!/usr/bin/env bash
# post-write-crlf-fix.sh: Auto-strip CRLF line endings from shell scripts after Write.
# Fires on PostToolUse (matcher: Write). The Write tool may produce CRLF on macOS.

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null)
[[ -z "$FILE_PATH" ]] && exit 0
[[ ! -f "$FILE_PATH" ]] && exit 0

# Only check shell scripts
case "$FILE_PATH" in
  *.sh|*.bash|*.zsh) ;;
  *) exit 0 ;;
esac

# Detect CRLF using file command
if file "$FILE_PATH" | grep -q "CRLF"; then
  sed -i '' 's/\r$//' "$FILE_PATH" 2>/dev/null || sed -i 's/\r$//' "$FILE_PATH" 2>/dev/null
fi

exit 0
