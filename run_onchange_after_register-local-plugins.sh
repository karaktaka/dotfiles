#!/usr/bin/env bash
# Idempotently registers local plugins in installed_plugins.json.
# Run by chezmoi after apply when script content changes.

INSTALLED_PLUGINS="${HOME}/.claude/plugins/installed_plugins.json"

register_local_plugin() {
  local plugin_key="$1"
  local install_path="$2"

  if [ ! -f "$INSTALLED_PLUGINS" ]; then
    echo '{"version":2,"plugins":{}}' > "$INSTALLED_PLUGINS"
  fi

  # Skip if already registered
  if jq -e --arg key "$plugin_key" '.plugins[$key]' "$INSTALLED_PLUGINS" > /dev/null 2>&1; then
    return 0
  fi

  local now
  now=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

  local tmp
  tmp=$(mktemp)
  jq --arg key "$plugin_key" \
     --arg path "$install_path" \
     --arg now "$now" \
     '.plugins[$key] = [{"scope":"user","installPath":$path,"version":"local","installedAt":$now,"lastUpdated":$now}]' \
     "$INSTALLED_PLUGINS" > "$tmp"
  mv "$tmp" "$INSTALLED_PLUGINS"
}

register_local_plugin "git-workflow@local" "${HOME}/.claude/plugins/local/git-workflow"
