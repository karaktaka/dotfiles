---
name: manage-mr
description: Create, update, or manage merge requests (GitLab) and pull requests (GitHub)
user-invocable: true
argument-hint: "[create|update|merge|close]"
---

# Manage Merge/Pull Request

Create, update, or manage merge requests (GitLab) and pull requests (GitHub).

## Prerequisites

Detect the platform from the remote URL - do NOT ask the user:

```bash
git remote get-url origin
```

| Remote contains | Platform | CLI | Term |
|-----------------|----------|-----|------|
| `github.com` | GitHub | `gh` | PR |
| Anything else | GitLab (self-hosted or `.com`) | `glab` | MR |

Verify the CLI is authenticated:

- GitHub: `gh auth status`
- GitLab: `glab auth status`

If the token is expired, ask the user to re-authenticate (`gh auth login` / `glab auth login`).

## Step 1: Gather Context

Run in parallel:

```bash
BRANCH=$(git branch --show-current)
DEFAULT_BRANCH=$(git remote show origin | sed -n 's/.*HEAD branch: //p')
```

```bash
git log --format="%H %s%n%b" ${DEFAULT_BRANCH}..HEAD
```

```bash
git diff ${DEFAULT_BRANCH}...HEAD
```

```bash
git diff ${DEFAULT_BRANCH}...HEAD --stat
```

Check if an MR/PR already exists:

- GitLab: `glab mr list --source-branch "${BRANCH}"`
- GitHub: `gh pr list --head "${BRANCH}"`

If updating, also fetch the existing description:

- GitHub: `gh pr view --json title,body`
- GitLab: `glab mr view --output json`

Try to detect a linked issue from the branch name (e.g. `AI-123/feature-name` or `42-feature-name`). If found, fetch it:

- GitHub: `gh issue view <number> --json title,body`
- GitLab: `glab issue view <number>`

## Step 2: Determine Action

| Condition | Action |
|-----------|--------|
| No existing MR/PR | **Create** |
| Exists, scope changed | **Update** title and/or description |
| User says "close" | Close without merging |
| User says "merge" | Merge (ask for squash preference) |

For **Create** and **Update**: proceed to Step 3. For **Merge** and **Close**: skip to Step 4.

## Step 3: Description agent

Spawn a **description agent** (subagent_type: `general-purpose`) passing the diff, commit log, linked issue (if found), and existing description (if updating).

### Description agent prompt

```
You are a pull/merge request description writer. Your job is to write a title and description that help reviewers understand the change - not summarise the code, which they can read themselves.

## Philosophy

The code is the source of truth. The description is a reading guide, not a transcript.

Reviewers will read the code. The description should help them understand:
1. **Why** - motivation in 1-2 sentences
2. **Non-obvious things** - what a reviewer would miss or misunderstand from the diff alone
3. **Caveats** - breaking changes, migration steps, ordering dependencies, things that look wrong but are intentional

## What NOT to include
- File-by-file changelogs - the diff shows this
- Obvious descriptions of what the code does
- Restating commit messages - reviewers can read `git log`
- Implementation details clear from reading the code
- Architecture diagrams or long explanations
- Excessive formatting, headers, or emoji

## Sizing guide
| Branch size | Description length |
|-------------|-------------------|
| 1-3 commits, single concern | 2-3 bullets, skip "Notes" section |
| 4-10 commits, one theme | 3-5 bullets + notes if non-obvious |
| 10+ commits or mixed themes | Short summary + notes + test plan |

## Context

Branch: <BRANCH>
Action: <create|update>

### Commit log
<paste full git log output>

### Diff stat
<paste git diff --stat output>

### Full diff
<paste git diff output>

### Linked issue (if available)
<paste issue title + body, or "None">

### Existing description (for updates only)
<paste current title + body, or "N/A">

## Output format

Return exactly two sections:

### TITLE
<Under 70 chars. Conventional commit prefix (feat:, fix:, refactor:, chore:, etc.). Describe the what, not the how.>

### DESCRIPTION
## Summary

- <bullet 1: big picture change>
- <bullet 2: second concern, if any>

## Notes for reviewers

<Only include if there are genuinely non-obvious things. Omit this section entirely otherwise.>

- <non-obvious thing>

## Test plan

- [ ] <verification step>
```

Wait for the agent to return `TITLE` and `DESCRIPTION` before proceeding.

## Step 4: Execute

### Create

**GitLab:**
```bash
glab mr create \
  --source-branch "${BRANCH}" \
  --target-branch "${DEFAULT_BRANCH}" \
  --title "<TITLE from agent>" \
  --description "$(cat <<'EOF'
<DESCRIPTION from agent>
EOF
)"
```

**GitHub:**
```bash
gh pr create \
  --head "${BRANCH}" \
  --base "${DEFAULT_BRANCH}" \
  --title "<TITLE from agent>" \
  --body "$(cat <<'EOF'
<DESCRIPTION from agent>
EOF
)"
```

Optional flags (ask user if relevant):

| Intent | GitLab | GitHub |
|--------|--------|--------|
| Draft | `--draft` | `--draft` |
| Assign to self | `--assignee @me` | `--assignee @me` |
| Add labels | `--label X` | `--label X` |
| Add reviewer | `--reviewer X` | `--reviewer X` |
| Delete branch on merge | `--remove-source-branch` | `--delete-branch` |

### Update

**GitLab:**
```bash
glab mr update ${MR_ID} \
  --title "<TITLE from agent>" \
  --description "$(cat <<'EOF'
<DESCRIPTION from agent>
EOF
)"
```

**GitHub:**
```bash
gh pr edit ${PR_ID} \
  --title "<TITLE from agent>" \
  --body "$(cat <<'EOF'
<DESCRIPTION from agent>
EOF
)"
```

### Merge

Use the `AskUserQuestion` tool to ask: "Merge this MR/PR? Verify the pipeline is green and changes are tested." with options: "Yes, merge now", "Cancel"

**GitLab:**
```bash
glab mr merge ${MR_ID} --squash --remove-source-branch
```

**GitHub:**
```bash
gh pr merge ${PR_ID} --squash --delete-branch
```

### Close

**GitLab:** `glab mr close ${MR_ID}`
**GitHub:** `gh pr close ${PR_ID}`

## Step 5: Confirm

Show the URL so the user can verify in the browser:

- GitLab: `glab mr view ${MR_ID} --web`
- GitHub: `gh pr view ${PR_ID} --web`

## Tips

- **Push first**: Ensure the branch is pushed before creating (`git push -u origin ${BRANCH}`)
- **Rebase if behind**: If the branch is behind target, suggest rebasing first
- **Draft for WIP**: Use `--draft` to avoid premature reviews
- **Stacked MRs/PRs**: If depending on another branch, set target accordingly
