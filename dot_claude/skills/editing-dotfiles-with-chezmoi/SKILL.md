---
name: editing-dotfiles-with-chezmoi
description: Use when modifying dotfiles, home directory configuration files, ~/.claude/CLAUDE.md, ~/.claude/ files, or any chezmoi-managed files. Also use when adding new config files to home directory.
---

# Editing Dotfiles with Chezmoi

Home directory files are managed by chezmoi. The workflow depends on whether the file is a **template** or a **regular file**.

## Check: Template, Encrypted, or Regular?

```bash
ls ~/.local/share/chezmoi/ | grep <filename>
# Ends in .tmpl        → Template (has conditionals like {{ .isWork }})
# Starts with encrypted_ → Encrypted with age (sensitive work data)
# Neither               → Regular file
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
#    e.g. ~/.local/share/chezmoi/dot_claude/CLAUDE.md.tmpl
# 2. Apply to target
chezmoi apply --force ~/path/to/file
# 3. Commit & push
git -C ~/.local/share/chezmoi add <changed-files>
git -C ~/.local/share/chezmoi commit -m "message"
git -C ~/.local/share/chezmoi push
```

## Workflow: Encrypted Files

Work-sensitive files (internal hostnames, account IDs, architecture docs) are age-encrypted in the chezmoi source. They appear as `encrypted_*.age` in git but deploy decrypted to the target. The dotfiles repo is **public** — encryption ensures sensitive data isn't readable on GitHub.

**Editing** — edit the target directly, then re-add (encryption is preserved):

```bash
# 1. Edit the target file normally
# 2. Sync back — chezmoi re-encrypts automatically
chezmoi re-add ~/path/to/encrypted/file
```

**Adding new sensitive files:**

```bash
chezmoi add --encrypt ~/path/to/new/sensitive/file
```

Also add the target path to `.chezmoiignore` under the `{{ if not .isWork }}` block so it's excluded on personal machines.

**Converting an existing plaintext file to encrypted:**

```bash
chezmoi forget --force ~/path/to/file
chezmoi add --encrypt ~/path/to/file
```

## Key Paths

| Target | Chezmoi source | Type |
|--------|---------------|------|
| `~/.claude/CLAUDE.md` | `CLAUDE.md.tmpl` | Template |
| `~/.claude/settings.json` | `dot_claude/settings.json.tmpl` | Template |
| `~/.claude/mcp.json` | `dot_claude/dot_mcp.json.tmpl` | Template |
| `~/.claude/commands/` | `dot_claude/commands/` | Regular (some encrypted) |
| `~/.claude/skills/` | `dot_claude/skills/` | Regular |
| `~/.claude/observability.md` | `dot_claude/encrypted_observability.md.age` | Encrypted |
| `~/.claude/kubernetes.md` | `dot_claude/encrypted_kubernetes.md.age` | Encrypted |
| `~/.local/bin/kn-workspace-init` | `dot_local/bin/encrypted_executable_kn-workspace-init.age` | Encrypted |

All source paths are relative to `~/.local/share/chezmoi/`.

## Adding New Files

```bash
chezmoi add ~/path/to/new/file
```

## Common Mistakes

- **Editing a template target directly** (`~/.claude/CLAUDE.md`, `~/.claude/settings.json`): Gets overwritten on next apply. Edit the `.tmpl` source.
- **`chezmoi add --force` on a template**: Destroys template conditionals. Edit `.tmpl` directly.
- **`chezmoi add` (without `--encrypt`) on a sensitive file**: Stores plaintext in the public git repo. Always use `--encrypt` for work-sensitive files.
- **Forgetting `.chezmoiignore`**: Encrypted files still deploy everywhere unless excluded. Add work-only files to the `{{ if not .isWork }}` block.
- **Forgetting to push**: Changes only persist across machines if committed and pushed to the chezmoi repo.
