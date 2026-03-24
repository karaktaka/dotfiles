# macOS Config Paths

- lazygit/k9s use `~/Library/Application Support/` on macOS, `~/.config/` on Linux
- lazygit follows symlinks; **k9s does NOT** (uses `lstat`) — needs real files at native path
- k9s per-cluster skins fully override global skin (no inheritance) — per-cluster skins must include the full theme
- Cross-platform chezmoi strategy: `.chezmoiignore` with OS conditionals for k9s; symlink script for lazygit
- k9s startup view: per-cluster state in `~/Library/Application Support/k9s/clusters/<ctx>/<cluster>/config.yaml` overrides CLI flags (`-n`, `-c`) — lock with `chmod 444`; view format is `v1/pods <namespace>`; k9s uses direct writes so dir permissions don't help
- Time Machine local snapshots: `/Volumes/com.apple.TimeMachine.localsnapshots/Backups.backupdb/`
- **macOS `sed -i`**: Requires empty string arg (`sed -i '' 's/.../.../'`) unlike GNU sed. For complex replacements, `perl -pi -e 's/old/new/g' file` avoids the platform difference entirely.
