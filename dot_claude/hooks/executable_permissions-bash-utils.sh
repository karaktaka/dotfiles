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

  npm)
    case "$COMMAND" in
      # Registry operations — always ask
      *"npm publish"*|*"npm adduser"*|*"npm login"*|*"npm logout"*|\
      *"npm owner"*|*"npm access"*|*"npm deprecate"*|*"npm unpublish"*)
        ask "npm registry operation — confirm intent" ;;
      # Package mutations — ask because npm packages can contain malicious code
      *"npm install "*|*"npm i "*|*"npm add "*|*"npm update"*|*"npm upgrade"*)
        ask "npm package install/update — review packages being added" ;;
      # Bare 'npm install' (restore from lockfile) — ask to be safe
      *"npm install"|*"npm i")
        ask "npm install (no args) — restores all dependencies from lockfile" ;;
      # Registry read operations — safe, no side effects
      *"npm info "*|*"npm show "*|*"npm view "*)
        allow "npm registry read (no mutations)" ;;
      # Safe local operations: run scripts, build, test, lint, audit, list
      *"npm run "*|*"npm test"*|*"npm start"*|*"npm build"*|*"npm ci"*|\
      *"npm ls"*|*"npm list"*|*"npm audit"*|*"npm outdated"*|*"npm pack"*)
        allow "Safe npm local operation (no package mutations)" ;;
    esac
    ask "Unknown npm command — confirm intent" ;;

  npx)
    case "$COMMAND" in
      # Known-safe linting, formatting, and type-checking tools
      *"npx prettier"*|*"npx eslint"*|*"npx tsc"*|*"npx stylelint"*|\
      *"npx markdownlint"*|*"npx jest"*|*"npx vitest"*|*"npx ruff"*)
        allow "npx with known-safe dev tool" ;;
    esac
    ask "npx may download and execute an npm package — confirm package name and intent" ;;

  # --- Go toolchain ---
  go)
    case "$COMMAND" in
      # Risky: executes code or mutates dependencies
      *"go run "*)       ask "go run — executes arbitrary Go code" ;;
      *"go generate"*)   ask "go generate — runs arbitrary //go:generate directives" ;;
      *"go install"*)    ask "go install — installs a binary (may download code)" ;;
      *"go get"*)        ask "go get — adds or updates module dependencies" ;;
      # Safe: build, analysis, formatting, module inspection
      *"go build"*|*"go test"*|*"go vet"*|*"go fmt"*|\
      *"go list"*|*"go doc"*|*"go env"*|*"go version"*|\
      *"go clean"*|*"go tool"*|\
      *"go mod tidy"*|*"go mod download"*|*"go mod verify"*|\
      *"go mod graph"*|*"go mod why"*|*"go mod edit"*|*"go mod vendor"*|\
      *"go work"*)
        allow "Safe go command (no code execution or dep mutation)" ;;
    esac
    ask "Unknown go subcommand — confirm intent" ;;

  gopls)
    allow "gopls — read-only Go language server / analysis tool" ;;

  # --- Unconditionally safe utilities ---
  # Yield first if a dangerous command appears after a chain operator so that
  # permissions-bash-dangerous.sh can make the call without conflicting.
  basename|cat|column|cut|date|diff|dig|dirname|du|echo|export|file|\
  gofmt|grep|head|hostname|id|jq|less|ls|md5|more|ping|prettier|pwd|realpath|\
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
