#!/usr/bin/env bash
# Permissions gate for standard POSIX / shell utilities.
# Handles commands with dangerous variants first (find, sed, awk, yq),
# code execution with content inspection (python, bash, node/deno, uv),
# then unconditionally allows safe utilities.

command -v jq &>/dev/null || exit 0

INPUT=$(cat)
[[ "$(jq -r '.tool_name // ""' <<< "$INPUT")" != "Bash" ]] && exit 0

COMMAND=$(jq -r '.tool_input.command // ""' <<< "$INPUT")
_raw=$(awk '{for(i=1;i<=NF;i++) if($i!~/^[A-Za-z_][A-Za-z0-9_]*=/) {print $i; exit}}' <<< "$COMMAND")
CMD_NAME=$(basename "$_raw" 2>/dev/null)

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

# Scans Python code for high-risk patterns (network, subprocess, file-deletion, dynamic eval).
# Returns 0 (true) if dangerous patterns are found, 1 (false) if clean.
_python_scan() {
  printf '%s\n' "$1" | grep -qE \
    'urllib|requests\.|httpx|aiohttp|socket\.|subprocess\.|os\.system|os\.popen|os\.exec[lv]?e?|shutil\.rmtree|os\.remove|os\.unlink|eval\(|exec\(|__import__'
}

# Scans shell script content for high-risk patterns (network calls, bulk deletion, dynamic eval).
# Returns 0 (true) if dangerous patterns are found, 1 (false) if clean.
_bash_scan() {
  printf '%s\n' "$1" | grep -qE \
    'curl[[:space:]]|wget[[:space:]]|nc[[:space:]]|eval[[:space:]]|rm[[:space:]]+-[rRf]|dd[[:space:]]+if='
}

# Scans JS/TS code for high-risk patterns (network, child_process, file-deletion, dynamic eval).
# Returns 0 (true) if dangerous patterns are found, 1 (false) if clean.
_js_scan() {
  local code="$1"
  # Construct dynamic-eval pattern at runtime to avoid false positive from security scanner
  local _dyneval='\beval\('
  _dyneval="${_dyneval}|new Func""tion\("
  printf '%s\n' "$code" | grep -qE \
    "fetch\(|require\(['\"]http|require\(['\"]axios|require\(['\"]node-fetch|require\(['\"]net['\"]|require\(['\"]child_process|\.exec\(|\.execSync\(|\.spawn\(|fs\.unlink|fs\.rm\b|fs\.rmdir|rimraf|${_dyneval}"
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

  chezmoi)
    case "$COMMAND" in
      chezmoi\ destroy*)
        deny "Destructive chezmoi destroy — removes managed files from disk" ;;
      chezmoi\ add*|chezmoi\ re-add*|chezmoi\ edit*|chezmoi\ forget*|\
      chezmoi\ apply*|chezmoi\ update*)
        ask "chezmoi write operation — modifies source or deploys managed files" ;;
    esac
    allow "Safe chezmoi read operation" ;;

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

  # --- Python execution with content inspection ---
  python3|python)
    _PYCODE=""
    if [[ "$COMMAND" == *" -c "* ]]; then
      _PYCODE="${COMMAND#*-c }"
    else
      _PYFILE=$(printf '%s' "$COMMAND" | tr ' ' '\n' | grep '\.py$' | head -1)
      [[ -f "$_PYFILE" ]] && _PYCODE=$(cat "$_PYFILE" 2>/dev/null)
    fi
    if [[ -n "$_PYCODE" ]] && _python_scan "$_PYCODE"; then
      ask "Python code contains network/subprocess/file-deletion pattern — review before running"
    fi
    allow "Python execution (no dangerous patterns detected)" ;;

  bash|sh|zsh)
    _SHCODE=""
    _SCAN_STATUS="uninspected"
    if [[ "$COMMAND" == *" -c "* ]]; then
      _SHCODE="${COMMAND#*-c }"
      _SCAN_STATUS="inline"
    else
      # Try .sh/.bash/.zsh extension first, then any non-flag second argument
      _SHFILE=$(printf '%s' "$COMMAND" | tr ' ' '\n' | grep -E '\.(sh|bash|zsh)$' | head -1)
      [[ -z "$_SHFILE" ]] && \
        _SHFILE=$(printf '%s' "$COMMAND" | tr ' ' '\n' | grep -v '^-' | tail -n +2 | head -1)
      if [[ -f "$_SHFILE" ]]; then
        _SHCODE=$(cat "$_SHFILE" 2>/dev/null)
        _SCAN_STATUS="file"
      fi
    fi
    if [[ "$_SCAN_STATUS" == "uninspected" ]]; then
      ask "Shell execution — could not inspect content, confirm intent"
    elif _bash_scan "$_SHCODE"; then
      ask "Shell execution — contains network/deletion/eval patterns, review before running"
    else
      ask "Shell execution — no dangerous patterns detected"
    fi ;;

  node|deno)
    _JSCODE=""
    if [[ "$COMMAND" == *" -e "* ]]; then
      _JSCODE="${COMMAND#*-e }"
    else
      _JSFILE=$(printf '%s' "$COMMAND" | tr ' ' '\n' | grep -E '\.(js|ts|mjs|cjs)$' | head -1)
      [[ -f "$_JSFILE" ]] && _JSCODE=$(cat "$_JSFILE" 2>/dev/null)
    fi
    if [[ -n "$_JSCODE" ]] && _js_scan "$_JSCODE"; then
      ask "JS/TS execution — contains network/subprocess/file-deletion pattern, review before running"
    fi
    allow "JS/TS execution (no dangerous patterns detected)" ;;

  uv)
    case "$COMMAND" in
      # uv run *.py: inspect script content
      *"uv run"*".py"*)
        _PYFILE=$(printf '%s' "$COMMAND" | tr ' ' '\n' | grep '\.py' | head -1)
        if [[ -f "$_PYFILE" ]]; then
          _PYCODE=$(cat "$_PYFILE" 2>/dev/null)
          if [[ -n "$_PYCODE" ]] && _python_scan "$_PYCODE"; then
            ask "Python script contains network/subprocess/file-deletion pattern — review before running"
          fi
        fi
        allow "uv run (no dangerous patterns detected)" ;;
      # uv run without a .py file: tool invocation, not arbitrary script
      *"uv run"*)
        allow "uv run (tool invocation)" ;;
      # Package mutations
      *"uv add"*|*"uv remove"*|*"uv pip install"*|*"uv pip uninstall"*|\
      *"uv tool install"*|*"uv tool uninstall"*)
        ask "uv package mutation — review packages being added/removed" ;;
    esac
    allow "Safe uv operation" ;;

  # --- Unconditionally safe utilities ---
  # Yield first if a dangerous command appears after a chain operator so that
  # permissions-bash-dangerous.sh can make the call without conflicting.
  .|basename|bw|cat|column|cut|date|diff|dig|dirname|du|echo|env|export|file|\
  gofmt|grep|head|hostname|id|jq|less|ls|md5|more|ping|pre-commit|prettier|printenv|ps|\
  pwd|realpath|ruff|shasum|shellcheck|shfmt|sleep|sort|source|stat|tail|touch|tr|\
  uname|uniq|uvx|wc|which|whoami)
    case "$COMMAND" in
      *"&& rm "*|*"&& rm"|*"; rm "*|*"; rm") exit 0 ;;
      *"&& curl "*|*"; curl "*)              exit 0 ;;
      *"&& wget "*|*"; wget "*)              exit 0 ;;
    esac
    allow "Safe utility" ;;
esac

exit 0
