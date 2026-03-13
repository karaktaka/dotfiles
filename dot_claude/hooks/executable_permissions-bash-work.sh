#!/usr/bin/env bash
# Permissions gate for work-specific commands.
# Self-disables when CLAUDE_CODE_USE_BEDROCK != true (non-work machines).
#
# Covered tools: aws, az, kubectl, helm, glab, jira, mark,
#                make (terraform targets), terraform, actionlint, act.

[[ "${CLAUDE_CODE_USE_BEDROCK:-false}" != "true" ]] && exit 0

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
  aws)
    case "$COMMAND" in
      aws*delete*|aws*terminate*) deny "Destructive AWS operation" ;;
    esac
    case "$COMMAND" in
      aws*create*|aws*modify*|aws*put*|aws*run*|\
      aws*start*|aws*stop*|aws*update*)              ask "AWS write operation" ;;
      "aws s3 cp "*|"aws s3 mv "*|"aws s3 rm "*|\
      "aws s3 sync "*)                                ask "S3 write operation" ;;
    esac
    allow "AWS CLI (read/safe)" ;;

  az)
    case "$COMMAND" in
      az*delete*|az*remove*|az*purge*) deny "Destructive Azure operation" ;;
    esac
    case "$COMMAND" in
      az*create*|az*update*|az*set*|az*add*|az*assign*|\
      az*start*|az*stop*|az*restart*|az*deploy*|az*import*) ask "Azure write operation" ;;
    esac
    allow "Azure CLI (read/safe)" ;;

  kubectl)
    # ── Context switch ──────────────────────────────────────────────────
    if [[ "$COMMAND" =~ kubectl.*config[[:space:]]+use-context[[:space:]]+([^[:space:]]+) ]]; then
      new_ctx="${BASH_REMATCH[1]}"
      [[ "$new_ctx" == *sandbox* ]] && allow "Switching to sandbox context"
      ask "Switching kubectl context to '$new_ctx' — subsequent commands target this cluster"
    fi

    # ── Resolve effective cluster context ───────────────────────────────
    # Prefer --context flag; fall back to current kubeconfig context.
    if [[ "$COMMAND" =~ --context[=[:space:]]+([^[:space:]]+) ]]; then
      kube_ctx="${BASH_REMATCH[1]}"
    else
      kube_ctx=$(kubectl config current-context 2>/dev/null || echo "unknown")
    fi

    # ── Sandbox cluster: all operations permitted ───────────────────────
    [[ "$kube_ctx" == *sandbox* ]] && allow "Sandbox cluster ($kube_ctx)"

    # ── Non-sandbox: restricted rules ──────────────────────────────────

    # Secrets are sensitive on any non-sandbox cluster
    case "$COMMAND" in
      kubectl*" secret "*|kubectl*" secrets "*|\
      kubectl*" secret"|kubectl*" secrets")
        ask "Reading Kubernetes secrets on '$kube_ctx' — may contain sensitive data" ;;
    esac

    # Destructive operations: ask
    case "$COMMAND" in
      kubectl*cordon*|kubectl*delete*|kubectl*drain*|\
      kubectl*remove*|kubectl*scale*)
        ask "Destructive kubectl on '$kube_ctx' — confirm intent" ;;
    esac

    # Read-only operations: allow
    case "$COMMAND" in
      "kubectl get"*|"kubectl describe"*|"kubectl logs"*|"kubectl top"*|\
      "kubectl version"*|"kubectl rollout status"*|\
      "kubectl config get-contexts"*|"kubectl config current-context"*|\
      "kubectl config view"*|"kubectl explain"*|\
      "kubectl api-resources"*|"kubectl api-versions"*)
        allow "kubectl read-only on '$kube_ctx'" ;;
    esac

    exit 0 ;;  # anything else: no decision

  helm)
    case "$COMMAND" in
      helm*lint*|helm*list*|helm*template*|helm*history*) allow "Helm read-only" ;;
    esac
    exit 0 ;;

  glab)
    # API: allow GET, ask for write methods
    case "$COMMAND" in
      glab*api*)
        case "$COMMAND" in
          *"-X POST"*|*"--method POST"*|\
          *"-X PUT"*|*"--method PUT"*|\
          *"-X PATCH"*|*"--method PATCH"*|\
          *"-X DELETE"*|*"--method DELETE"*)
            ask "glab api write operation — confirm method and endpoint" ;;
        esac
        allow "glab api (read — GET)" ;;
    esac
    # Safe read operations
    case "$COMMAND" in
      "glab --version"*|"glab auth status"*|\
      glab*mr*list*|glab*mr*view*|glab*mr*diff*|glab*mr*note*list*|\
      glab*mr*approvals*|glab*mr*checks*|\
      glab*issue*list*|glab*issue*view*|glab*issue*note*list*|\
      glab*ci*list*|glab*ci*view*|glab*ci*status*|\
      glab*pipeline*list*|glab*pipeline*view*|glab*pipeline*status*|\
      glab*repo*view*|glab*repo*list*|\
      glab*release*list*|glab*release*view*|\
      glab*label*list*|\
      glab*milestone*list*|\
      glab*variable*list*|glab*variable*get*|\
      glab*user*get*|glab*user*list*)
        allow "GitLab CLI read-only" ;;
    esac
    ask "GitLab CLI — may mutate remote state" ;;

  jira)
    case "$COMMAND" in
      "jira epic"*|"jira issue list"*|"jira issue view"*|"jira sprint"*) allow "Jira read-only" ;;
      jira*issue*comment*|jira*issue*create*|jira*issue*edit*)            ask "Jira write operation" ;;
    esac
    exit 0 ;;

  mark)
    case "$COMMAND" in
      mark*--compile-only*|mark*--dry-run*) allow "Confluence dry-run" ;;
      *) ask "Confluence publish — updates live page" ;;
    esac ;;

  make)
    case "$COMMAND" in
      make*tf/format*|make*tf/init*|make*tf/plan*|\
      make*init-*|make*plan-*)                         allow "Terraform plan/init (read-only)" ;;
      make*apply-*|make*destroy-*|make*tf/apply*|\
      make*tf/destroy*|make*tf/import*|make*tf/state*) ask "Infrastructure apply/destroy" ;;
    esac
    exit 0 ;;

  terraform)
    case "$COMMAND" in
      terraform*fmt*|terraform*validate*) allow "Terraform validate (read-only)" ;;
    esac
    exit 0 ;;

  actionlint|act)
    allow "CI lint/test tooling" ;;
esac

exit 0
