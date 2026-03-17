# Observability (Grafana/Loki)

## Grafana URLs
- **dev + sandbox**: `grafana.nonprod.example.com` — covers `apps-dev-cluster` and sandbox cluster
- **prod**: `grafana.prod.example.com` — `apps-prod-cluster`

## Querying Logs via CLI
- Use Grafana session cookie (no K8s access needed)
- `export GRAFANA_SESSION_DEV=<cookie>` / `GRAFANA_SESSION_PROD=<cookie>`
- Get cookie: browser DevTools → Application → Cookies → `grafana_session`
- Query via `/api/datasources/proxy/<id>/loki/api/v1/query_range` (POST with `--data-urlencode`)
- Default datascience datasource: `aie-grafana-loki` (id 221 on dev)

## Direct Loki Auth
- OAuth2 client credentials from `monitoring/alloy-oauth2-credentials` K8s secret
- Token endpoint is AWS Cognito — only `client_credentials` grant supported, no personal user CLI auth

## Tenant/Cluster Mapping
- Check the Alloy configmap in `monitoring` ns for `tenant_id` and `external_labels`
