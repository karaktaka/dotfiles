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

    # Extract kubectl verb (first positional arg, skipping flags and their values).
    # Uses read -ra to avoid glob expansion on custom-columns or field-selector values.
    kubectl_verb=""
    _skip_val=false
    IFS=' ' read -ra _words <<< "$COMMAND"
    for _word in "${_words[@]}"; do
      $_skip_val && { _skip_val=false; continue; }
      [[ "$_word" == "kubectl" ]] && continue
      [[ "$_word" == "|" || "$_word" == "&&" || "$_word" == "||" ]] && break
      case "$_word" in
        --context|--namespace|-n|--kubeconfig|--output|-o|\
        --field-selector|--selector|-l|--user|--cluster|--server|\
        --token|--as|--as-group|--subresource|--sort-by|\
        --certificate-authority|--client-certificate|--client-key)
          _skip_val=true; continue ;;
      esac
      [[ "$_word" == -* ]] && continue
      kubectl_verb="$_word"
      break
    done

    # Read-only operations: allow by verb
    case "$kubectl_verb" in
      get|describe|logs|top|version|explain|api-resources|api-versions)
        allow "kubectl read-only on '$kube_ctx'" ;;
      rollout)
        [[ "$COMMAND" == *"rollout status"* ]] && allow "kubectl read-only on '$kube_ctx'" ;;
      config)
        case "$COMMAND" in
          *"get-contexts"*|*"current-context"*|*"config view"*)
            allow "kubectl read-only on '$kube_ctx'" ;;
        esac ;;
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
    # Sandbox: all operations permitted (test account)
    case "$COMMAND" in
      *sandbox*) allow "Sandbox environment" ;;
    esac

    # Read-only: terraform + terragrunt
    case "$COMMAND" in
      make*tf/format*|make*tf/init*|make*tf/plan*|\
      make*tf/output*|make*tf/module-docs*|\
      make*tf/state-list*|make*tf/state-show*|\
      make*init-*|make*plan-*|\
      make*tg/format*|make*tg/init*|\
      make*tg/validate*|make*tg/plan*|\
      make*tg/output*|\
      make*tg/state-list*|make*tg/state-show*)  allow "Terraform/Terragrunt read-only" ;;
    esac

    # State-mutating / destructive
    case "$COMMAND" in
      make*apply-*|make*destroy-*|\
      make*tf/apply*|make*tf/destroy*|\
      make*tf/import*|make*tf/refresh*|make*tf/unlock-state*|\
      make*tf/state-rm*|make*tf/state-mv*|make*tf/state-import*|\
      make*tg/apply*|make*tg/destroy*|\
      make*tg/state-rm*|make*tg/state-mv*|\
      make*tg/state-import*|make*tg/unlock-state*)  ask "Infrastructure apply/destroy/state-mutate" ;;
    esac
    exit 0 ;;

  terraform)
    # Sandbox: all operations permitted (test account)
    case "$COMMAND" in
      *sandbox*) allow "Sandbox environment" ;;
    esac

    case "$COMMAND" in
      terraform*fmt*|\
      terraform*validate*|\
      terraform*plan*|\
      terraform*init*|\
      terraform*show*|\
      terraform*output*|\
      terraform*state*list*|terraform*state*show*|\
      terraform*workspace*list*|terraform*workspace*show*|\
      terraform*providers*|\
      terraform*version*|\
      terraform*graph*)  allow "Terraform read-only" ;;
    esac
    exit 0 ;;

  terragrunt)
    # Sandbox: all operations permitted (test account)
    case "$COMMAND" in
      *sandbox*) allow "Sandbox environment" ;;
    esac

    case "$COMMAND" in
      terragrunt*hclfmt*|\
      terragrunt*fmt*|\
      terragrunt*validate*|\
      terragrunt*plan*|\
      terragrunt*init*|\
      terragrunt*show*|\
      terragrunt*output*|\
      terragrunt*state*list*|terragrunt*state*show*|\
      terragrunt*workspace*list*|terragrunt*workspace*show*|\
      terragrunt*providers*|\
      terragrunt*version*|\
      terragrunt*graph*|\
      terragrunt*run-all*validate*|\
      terragrunt*run-all*plan*|\
      terragrunt*run-all*init*|\
      terragrunt*run-all*show*|\
      terragrunt*run-all*output*|\
      terragrunt*run-all*state*list*)  allow "Terragrunt read-only" ;;
    esac
    exit 0 ;;

  actionlint|act)
    allow "CI lint/test tooling" ;;
esac

exit 0
