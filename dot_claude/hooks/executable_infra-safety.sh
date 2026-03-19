#!/usr/bin/env bash
# infra-safety.sh
# Shows current kubectl context and AWS_PROFILE before infrastructure commands.
# Claude Code PreToolUse hook — provides informational context, never blocks.

source ~/.claude/hooks/hook-lib.sh || exit 0

# Short-circuit: skip all checks for the vast majority of non-infra commands
[[ "$COMMAND" != *kubectl* && "$COMMAND" != *terraform* && "$COMMAND" != *terragrunt* ]] && exit 0

if [[ "$COMMAND" == *kubectl* ]]; then
  ctx=$(kubectl config current-context 2>/dev/null || echo "unknown")
  echo "⚠️  kubectl context: $ctx"
fi

if [[ "$COMMAND" == *terraform* ]] || [[ "$COMMAND" == *terragrunt* ]]; then
  profile="${AWS_PROFILE:-default}"
  echo "⚠️  AWS_PROFILE: $profile"
fi

exit 0
