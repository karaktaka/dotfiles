---
name: pr-flair-reminder
enabled: true
event: bash
action: block
conditions:
  - field: command
    operator: regex_match
    pattern: gh\s+(pr|mr)\s+create
  - field: command
    operator: contains
    pattern: "Co-Authored-By:"
---

🚫 **Wrong flair in PR/MR body!**

You used `get-flair.sh` without `--mr`, putting a `Co-Authored-By:` line in the PR body. That belongs in commit messages only.

**Fix:** Replace the flair output in the body with:
```
~/.claude/get-flair.sh --dir <repo-path> --mr <type>
```

- **PR/MR body** → `get-flair.sh --dir <repo-path> --mr <type>` → produces a quote or `🤖 Generated with [Claude Code](...)`
- **Commit message** → `get-flair.sh --dir <repo-path> <type>` → produces `Co-Authored-By: Name <email>`
