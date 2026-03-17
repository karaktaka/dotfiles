# AWS & Kubernetes

## SSO & Auth
- SSO: `aws sso login --sso-session KN-Operations`
- Profiles: `dev`, `dev_op`, `prod`, `prod_op`, `sandbox`, `sandbox_op`
- **Prefer `_op` profiles** — plain profiles (`dev`, `prod`, `sandbox`) are limited DevelopmentEngineer (mostly read-only); `_op` profiles use the AIE OperationsEngineer role with full permissions
- Update kubectl binary to match cluster version: `update_kubectl` (does NOT update kubeconfig contexts)

## Contexts
- Check available contexts: `kubectl config get-contexts` — context names are full ARNs (e.g. `arn:aws:eks:eu-central-1:...:cluster/apps-prod-cluster`)
- **ALWAYS verify kubectl context before any kubectl command**: run `kubectl config current-context` first
- **Pass `--context=<name>` directly** to each command — never rely on ambient context being set correctly
- **Confirm target cluster** (sandbox/dev/prod) with user before any mutating operation

## Logs
- Pod log retention is very short (minutes to ~1 hour due to kubelet rotation) — for historical logs, query Loki instead
