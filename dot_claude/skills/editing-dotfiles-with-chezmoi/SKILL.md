---
name: editing-dotfiles-with-chezmoi
description: Use when modifying dotfiles, home directory configuration files, ~/CLAUDE.md, ~/.claude/ files, or any chezmoi-managed files. Also use when adding new config files to home directory.
---

# Editing Dotfiles with Chezmoi

Home directory files are managed by chezmoi. The workflow depends on whether the file is a **template** or a **regular file**.

## Check: Template or Regular?

```bash
ls ~/.local/share/chezmoi/ | grep <filename>
# Ends in .tmpl → Template (has conditionals like {{ .isWork }})
# No .tmpl suffix → Regular file
```

## Workflow: Regular Files

Edit the target file directly, then sync back to chezmoi:

```bash
# 1. Edit the file directly (e.g. ~/.claude/commands/my-command.md)
# 2. Sync back to chezmoi source
chezmoi re-add ~/path/to/file
# 3. Commit & push
git -C ~/.local/share/chezmoi add <changed-files>
git -C ~/.local/share/chezmoi commit -m "message"
git -C ~/.local/share/chezmoi push
```

## Workflow: Template Files

**Never edit the target file directly** — edits will be overwritten. Edit the `.tmpl` source instead:

```bash
# 1. Edit the template in chezmoi source
#    e.g. ~/.local/share/chezmoi/CLAUDE.md.tmpl
# 2. Apply to target
chezmoi apply --force ~/path/to/file
# 3. Commit & push
git -C ~/.local/share/chezmoi add <changed-files>
git -C ~/.local/share/chezmoi commit -m "message"
git -C ~/.local/share/chezmoi push
```

## Key Paths

| Target | Chezmoi source | Type |
|--------|---------------|------|
| `~/CLAUDE.md` | `CLAUDE.md.tmpl` | Template |
| `~/.claude/settings.json` | `dot_claude/settings.json.tmpl` | Template |
| `~/.claude/mcp.json` | `dot_claude/dot_mcp.json.tmpl` | Template |
| `~/.claude/commands/` | `dot_claude/commands/` | Regular |
| `~/.claude/skills/` | `dot_claude/skills/` | Regular |

All source paths are relative to `~/.local/share/chezmoi/`.

## Adding New Files

```bash
chezmoi add ~/path/to/new/file
```

## Common Mistakes

- **Editing a template target directly** (`~/CLAUDE.md`, `~/.claude/settings.json`): Gets overwritten on next apply. Edit the `.tmpl` source.
- **`chezmoi add --force` on a template**: Destroys template conditionals. Edit `.tmpl` directly.
- **Forgetting to push**: Changes only persist across machines if committed and pushed to the chezmoi repo.
