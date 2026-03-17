Create a new git branch. Follow the git workflow and branch naming conventions from @CLAUDE.md.

## Steps

1. Check for uncommitted changes or staged files:
```bash
git status --porcelain
git diff --name-only
```

2. Generate a branch name based on the naming conventions — strategy depends on whether changes exist.

3. Create the branch:
```bash
git switch -c <generated-name>
```

Confirm the branch was created successfully.
