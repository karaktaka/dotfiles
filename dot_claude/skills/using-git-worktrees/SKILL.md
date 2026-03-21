---
name: using-git-worktrees
description: Use when starting feature work that needs isolation — creating worktrees, switching to a worktree, running commands in a worktree, or cleaning up worktrees. Trigger when the user asks to start a feature branch, work on multiple things in parallel, or explicitly mentions worktrees.
---

# Working with Git Worktrees

Worktrees provide isolated working directories for each branch — no stashing, no context switching. Once inside a worktree, **stay there for the entire session** and run all commands normally without path flags.

## When to Use Worktrees

- **Use a worktree** for feature work, bug fixes with non-trivial scope, or parallel work
- **Use a regular branch** (`git switch -c`) only for quick single-file fixes

## Creating and Entering a Worktree

**Using the `EnterWorktree` tool** (preferred when user explicitly says "worktree"):

Call `EnterWorktree` with a descriptive name. This creates the worktree under `.claude/worktrees/` inside the project and **automatically switches the session's CWD** into it.

**Manually with git** (when coordinating with an existing branch or using the `.worktrees/` convention):

```bash
git worktree add .worktrees/<branch-name> -b <branch-name>
```

Then `cd` into it as the **first and only** move — stay there for the rest of the session:

```bash
cd .worktrees/<branch-name>
```

Confirm with:
```bash
git worktree list
```

## Write a Context File Inside the Worktree

After entering the worktree, write a `WORKTREE.md` at its root capturing what is being worked on. This file is automatically deleted when the worktree is removed — no manual cleanup needed.

```markdown
# Worktree Context

Branch: <branch-name>
Goal: <one-line description of what is being built/fixed>
Related issue/PR: <link or N/A>

## Why this worktree
<reason for isolation — parallel work, risky change, long-running feature>
```

## Running Commands Inside the Worktree

Once the CWD is the worktree (via `EnterWorktree` or `cd`), run everything normally — no `-C` or `--directory` flags needed:

```bash
git status
git add <files>
git commit -m "feat: ..."
git push -u origin <branch>
uv run pytest
go build .
npm run build
```

**`gh` has no `-C` flag** — always reference by branch name or PR number:

```bash
gh pr view <branch-name> --repo owner/repo
gh pr create --head <branch-name>
```

**Frontend deps** — if `npm run build` fails with "command not found", run `npm install` first. Do not fiddle with PATH.

## Finishing Up

**Via `ExitWorktree` tool** (when entered with `EnterWorktree`):

- `action: "keep"` — work in progress, come back later
- `action: "remove"` — branch merged or work abandoned; deletes the directory and branch

**Manually** (when entered with `git worktree add` + `cd`):

```bash
git worktree remove .worktrees/<branch-name>
git branch -d <branch-name>
```

Prune stale entries after manual deletion:

```bash
git worktree prune
```

In both cases, `WORKTREE.md` is deleted automatically with the worktree directory.

Use `/clean_gone` to bulk-remove all branches already deleted on the remote.
