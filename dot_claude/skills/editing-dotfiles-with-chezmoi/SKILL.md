---
name: editing-dotfiles-with-chezmoi
description: Use when modifying dotfiles, home directory configuration files, ~/.claude/CLAUDE.md, ~/.claude/ files, or any chezmoi-managed files. Also use when adding new config files to home directory.
---

# Editing Dotfiles with Chezmoi

Home directory files are managed by chezmoi. The workflow depends on whether the file is a **template**, a **work file** (served from the private companion repo), or a **regular file**.

## Check: Template, Work File, or Regular?

```bash
ls ~/.local/share/chezmoi/ | grep <filename>
# Ends in .tmpl        → Template (has conditionals like {{ .isWork }})
# Neither               → Regular file
```

Work-only files use a two-repo architecture:
- **Symlink overlay** (primary): `chezmoi-overlay.map` in the work repo maps files → chezmoi source as symlinks. Git hooks auto-sync on commit.
- **Native includes** (SSH `Include`, git `[include]`, zsh `source`) for mixed-content files
- **Include templates** (few remaining): `.tmpl` files with `{{ include }}` for files needing template evaluation or mixed personal+work content

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

## Workflow: Work Files

Work-sensitive files live in a private companion repo at `~/.local/share/work-dotfiles/`. Most are served via a **symlink overlay** — the work repo's `chezmoi-overlay.map` maps files into the chezmoi source as symlinks.

**Editing work-only content** — edit in the work repo, then commit:

```bash
# 1. Edit the file in the work repo
#    e.g. ~/.local/share/work-dotfiles/claude/kubernetes.md
# 2. Commit & push (git hook auto-deploys to $HOME)
git -C ~/.local/share/work-dotfiles add <changed-files>
git -C ~/.local/share/work-dotfiles commit -m "message"
git -C ~/.local/share/work-dotfiles push
```

**Adding new work-only files:**

1. Add the file to the work repo under the appropriate directory
2. Add a line to `chezmoi-overlay.map` (tab-separated: work-repo-path, chezmoi-source-path, target-path)
3. Commit — the post-commit hook syncs automatically

## Key Paths

| Target | Chezmoi source | Type |
|--------|---------------|------|
| `~/.claude/CLAUDE.md` | `dot_claude/CLAUDE.md.tmpl` | Template |
| `~/.claude/settings.json` | `dot_claude/settings.json.tmpl` | Template: `isWork` branch includes `work-dotfiles/claude/settings.json` (edit there on work machines); `else` branch has standalone personal config |
| `~/.claude/commands/` | `dot_claude/commands/` | Regular |
| `~/.claude/skills/` | `dot_claude/skills/` | Regular |
| `~/.claude/kubernetes.md` | `dot_claude/kubernetes.md` → symlink | Overlay (work repo) |
| `~/.claude/observability.md` | `dot_claude/observability.md` → symlink | Overlay (work repo) |
| `~/.local/bin/workspace-init` | `dot_local/bin/executable_workspace-init` → symlink | Overlay (work repo) |
| `~/.ssh/config` | `private_dot_ssh/encrypted_config.age` | Encrypted (age) |
| `~/.gitconfig` | `dot_gitconfig.tmpl` | Template (uses `[include]`) |

All source paths are relative to `~/.local/share/chezmoi/`. Overlay symlinks are auto-managed — don't edit them directly.

## Adding New Files

```bash
chezmoi add ~/path/to/new/file
```

## Common Mistakes

- **Editing a template target directly** (`~/.claude/CLAUDE.md`, `~/.claude/settings.json`): Gets overwritten on next apply. Edit the `.tmpl` source.
- **`chezmoi add --force` on a template**: Destroys template conditionals. Edit `.tmpl` directly.
- **Editing work content in the public repo**: Work-only content belongs in `~/.local/share/work-dotfiles/`, not in the chezmoi source.
- **Editing the personal branch of a template on a work machine**: Some templates (e.g. `settings.json.tmpl`) have separate `isWork`/`else` branches. On a work machine, the `isWork` branch is active - its content comes from the work repo. Editing the `else` (personal) branch has no effect here. Check which branch applies before editing.
- **Forgetting `.chezmoiignore`**: Work-only files still deploy everywhere unless excluded. Add work-only files to the `{{ if not .isWork }}` block.
- **Forgetting to push both repos**: Work content changes need pushing in the work repo. Template changes need pushing in the chezmoi repo.
