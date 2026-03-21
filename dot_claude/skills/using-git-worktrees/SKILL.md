---
name: using-git-worktrees
description: Use when starting any branch work — creating worktrees, entering a worktree, running commands in a worktree, or cleaning up worktrees. Every branch gets its own worktree, regardless of change size. Trigger when the user asks to start a feature, fix a bug, or begin any branch-based work.
---

# Working with Git Worktrees

Every branch gets its own worktree — no exceptions. This guarantees that all tools (Bash, Read, Glob, Grep, Write) operate in the correct directory and can never accidentally read or modify the main checkout.

## Creating and Entering a Worktree

Always use the `EnterWorktree` tool. It creates a worktree under `.claude/worktrees/` inside the project and switches the **session-level CWD** for all tools — no `-C`, `--directory`, or `--prefix` flags needed anywhere.

```
EnterWorktree(name: "<descriptive-branch-name>")
```

Use a name that matches the branch intent (e.g. `feat-user-auth`, `fix-null-pointer`).

## Write a Context File

After entering the worktree, write a `WORKTREE.md` at its root. This file is automatically deleted when the worktree is removed — no manual cleanup needed.

```markdown
# Worktree Context

Branch: <branch-name>
Goal: <one-line description>
Related issue/PR: <link or N/A>
```

## Running Commands

Once inside the worktree, run everything normally — the session CWD is the worktree:

```bash
git status
git add <files>
git commit -m "feat: ..."
git push -u origin <branch>
uv run pytest
go build .
npm run build
```

**`gh` has no `-C` flag** — reference by branch name or PR number:

```bash
gh pr view <branch-name> --repo owner/repo
gh pr create --head <branch-name>
```

**Frontend deps** — if `npm run build` fails with "command not found", run `npm install` first. Do not fiddle with PATH.

## Finishing Up

Use `ExitWorktree` when done:

- `action: "keep"` — work in progress, return to it later
- `action: "remove"` — branch merged or abandoned; deletes the worktree directory and branch

`WORKTREE.md` is deleted automatically along with the worktree directory.

Use `/clean_gone` to bulk-remove all branches already deleted on the remote.
