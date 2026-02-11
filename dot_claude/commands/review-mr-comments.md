# Review MR Comments

Fetch and review comments from a GitLab Merge Request for the current branch.

## Prerequisites Check

First, verify that `glab` (GitLab CLI) is installed:

```bash
glab --version
```

If `glab` is not installed, ask the user:
- "The `glab` CLI is not installed. Would you like me to provide manual steps to review MR comments instead?"

If `glab` is installed, test authentication:

```bash
glab auth status
```

If the token is expired (401 error or "Token is expired" message), ask the user:
- "Your GitLab token has expired. Please run `glab auth login` to refresh it, then ask me to check again. Alternatively, I can provide manual steps."

## MR Review Process

### Step 1: Find the MR for Current Branch

```bash
BRANCH=$(git branch --show-current)
glab mr list --source-branch "${BRANCH}"
```

If no MR is found, inform the user and ask if they want to provide an MR number manually.

### Step 2: Get MR Discussions/Comments

Extract the MR number (e.g., `!3976` → `3976`) and fetch discussions:

```bash
PROJECT_PATH=$(git remote get-url origin | sed -E 's/.*gitlab[^\/]*[:\/]([^\.]+)(\.git)?/\1/' | sed 's/\//%2F/g')
MR_NUMBER=<number-from-step-1>
glab api "projects/${PROJECT_PATH}/merge_requests/${MR_NUMBER}/discussions" | jq -r '.[] | select(.notes[0].system == false) | .notes[] | select(.system == false) | "---\nAuthor: \(.author.name)\nResolved: \(.resolved // false)\nFile: \(.position.new_path // "general")\nLine: \(.position.new_line // "N/A")\n\n\(.body)\n"'
```

### Step 3: Analyze and Summarize Comments

For each unresolved comment:
1. **Identify the file and line** being commented on
2. **Understand the feedback** - what is the reviewer asking for?
3. **Categorize the comment type:**
   - Style/formatting suggestion
   - Bug fix request
   - Architecture/design concern
   - Documentation request
   - Question/clarification needed

### Step 4: Present Summary to User

Create a summary table with:
- Author name
- File and line number
- Brief description of the feedback
- Suggested action

**Do NOT automatically make changes.** Instead, present the summary and ask the user:
- "I found X unresolved comments. Here's a summary of what each reviewer is asking for and what changes would be needed. How would you like to proceed?"

Provide options:
1. **Apply all suggestions** - Make all requested changes
2. **Apply specific suggestions** - Let user choose which to apply
3. **Discuss with reviewer** - User will respond to comments manually
4. **Skip** - Do nothing for now

### Step 5: If User Chooses to Apply Changes

For each comment being addressed:
1. Read the relevant file
2. Make the requested change
3. Show the diff to the user before committing
4. Commit with a message referencing the review feedback

## Manual Steps (if glab unavailable)

If the user cannot use `glab`:

1. **Get the branch name:**
   ```bash
   git branch --show-current
   ```

2. **Open GitLab MR in browser:**
   Navigate to: `<project-url>/-/merge_requests?source_branch=<branch-name>`

3. **Review comments manually:**
   - Look at the "Changes" tab for inline comments
   - Check the "Overview" tab for general discussion
   - Note which comments are resolved vs unresolved

4. **Report back:**
   Tell the user which comments you found and ask how to proceed

## Comment Response Best Practices

When addressing review comments:
- **Style changes**: Usually safe to apply directly
- **Logic changes**: Verify understanding before applying
- **Architecture concerns**: Discuss with user before major refactoring
- **Questions**: May need user input to answer properly

Always create a **new commit** (or amend appropriately per project guidelines) with a clear message indicating the review feedback is being addressed.
