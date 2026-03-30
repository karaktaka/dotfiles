---
paths:
  - "**/dot_*"
  - "**/*.tmpl"
  - "**/chezmoi*"
  - "**/.chezmoiignore"
  - "**/.chezmoiexternal*"
---

**STOP** - Read `~/.claude/chezmoi.md` before making changes to chezmoi-managed files.
Use the `editing-dotfiles-with-chezmoi` skill for the full workflow.

Key reminders:
- Never edit template targets directly (e.g. `~/.claude/settings.json`) - edit the `.tmpl` source
- Hook scripts use `executable_` prefix in chezmoi source
- Autocommit fires on `chezmoi add` - use direct source edits + manual git commit instead
- Go template whitespace: `{{-` trims before, `-}}` trims after
