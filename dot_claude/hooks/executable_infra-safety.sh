#!/usr/bin/env bash
# infra-safety.sh
# Shows current kubectl context and AWS_PROFILE before infrastructure commands.
# Claude Code PreToolUse hook — provides informational context, never blocks.

INPUT=$(cat 2>/dev/null || echo "{}")
COMMAND=$(printf '%s' "$INPUT" | jq -r '.command // ""' 2>/dev/null || echo "")

if [[ "$COMMAND" == *kubectl* ]]; then
    ctx=$(kubectl config current-context 2>/dev/null || echo "unknown")
    echo "⚠️  kubectl context: $ctx"
fi

if [[ "$COMMAND" == *terraform* ]] || [[ "$COMMAND" == *terragrunt* ]]; then
    profile="${AWS_PROFILE:-default}"
    echo "⚠️  AWS_PROFILE: $profile"
fi

exit 0
