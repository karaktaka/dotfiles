# Chezmoi (Dotfiles)

## Key Rules
- **Never edit template targets directly** (`~/.claude/CLAUDE.md`, `~/.claude/settings.json`) — edits get overwritten. Edit the `.tmpl` source.
- Full workflow in `editing-dotfiles-with-chezmoi` skill (`~/.claude/skills/`)

## Operational Gotchas
- `chezmoi forget` needs `--force` in non-interactive shells (no TTY for confirmation)
- Autocommit fires on `chezmoi add`/`re-add`/`forget` — direct source edits need manual `git -C ~/.local/share/chezmoi` commit
- **Hook scripts** in `~/.claude/hooks/` are chezmoi-managed — stored as `executable_<name>.sh` in `dot_claude/hooks/`. To add a new hook: copy with the `executable_` prefix, stage manually, commit (don't use `chezmoi add` to avoid autocommit on a partial change).
- **Searching chezmoi source with Glob**: files use chezmoi prefixes (`dot_`, `executable_`, `.tmpl`) — search for those, not the rendered target names (e.g. `dot_claude/hooks/executable_*.sh`, not `~/.claude/hooks/*.sh`).
- **XDG git ignore**: `~/.config/git/ignore` is git's default global excludes file. Setting `core.excludesfile` overrides it entirely (no merging) — prefer adding entries to the XDG file instead.
- **Go template whitespace**: `{{- if }}` (left-dash) trims before — preserves indentation of next line. `{{ if -}}` (right-dash) trims after — use for block-level conditionals. Inline for single values: `{{ if .x }}val1{{ else }}val2{{ end }}`
