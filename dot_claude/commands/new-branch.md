Create a new git branch following these rules:

## Branch Name Generation

### Step 1: Check for existing changes
First, check if there are any uncommitted changes or staged files:
```bash
git status --porcelain
git diff --name-only
```

### Step 2: Generate branch name

Follow the naming conventions in @branch-naming.md — choose the appropriate strategy based on whether changes exist.

### Step 3: Create the branch
```bash
git checkout -b <generated-name>
```

Confirm the branch was created successfully.
