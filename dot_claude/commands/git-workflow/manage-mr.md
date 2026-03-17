# Manage Merge/Pull Request

Create, update, or manage merge requests (GitLab) and pull requests (GitHub).

## Prerequisites

Detect the platform from the remote URL — do NOT ask the user:

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
git log --oneline ${DEFAULT_BRANCH}..HEAD
```

```bash
git diff ${DEFAULT_BRANCH}...HEAD --stat
```

Check if an MR/PR already exists:

- GitLab: `glab mr list --source-branch "${BRANCH}"`
- GitHub: `gh pr list --head "${BRANCH}"`

## Step 2: Determine Action

| Condition | Action |
|-----------|--------|
| No existing MR/PR | **Create** |
| Exists, scope changed | **Update** title and/or description |
| User says "close" | Close without merging |
| User says "merge" | Merge (ask for squash preference) |

## Step 3: Write the Description

### Title

- Under 70 characters
- Conventional commit prefix: `feat:`, `fix:`, `refactor:`, `chore:`, etc.
- Describe the **what**, not the **how**

### Description Philosophy

**The code is the source of truth. The description is a reading guide, not a transcript.**

Reviewers will read the code. The description should help them understand:

1. **Why** — motivation in 1-2 sentences
2. **Non-obvious things** — what a reviewer would miss or misunderstand from the diff alone
3. **Caveats** — breaking changes, migration steps, ordering dependencies, things that look wrong but are intentional

### Template

```markdown
## Summary

- <bullet 1: big picture change>
- <bullet 2: second concern, if any>

## Notes for reviewers

<Only include this section if there are genuinely non-obvious things.>

- <e.g., "The `moved` block avoids a destroy/recreate — not a no-op">
- <e.g., "Import blocks adopt existing resources — IDs found via API">
- <e.g., "`!var.x` derivation is intentional to prevent invalid state">

## Test plan

- [ ] <verification step 1>
- [ ] <verification step 2>
```

### What NOT to include

- File-by-file changelogs — the diff shows this
- Obvious descriptions of what the code does
- Restating commit messages — reviewers can read `git log`
- Implementation details clear from reading the code
- Architecture diagrams or long explanations — those belong in README/docs
- Excessive formatting, headers, or emoji

### Sizing guide

| Branch size | Description length |
|-------------|-------------------|
| 1-3 commits, single concern | 2-3 bullets, skip "Notes" section |
| 4-10 commits, one theme | 3-5 bullets + notes if non-obvious |
| 10+ commits or mixed themes | Short summary + notes + test plan |

## Step 4: Execute

### Create

**GitLab:**
```bash
glab mr create \
  --source-branch "${BRANCH}" \
  --target-branch "${DEFAULT_BRANCH}" \
  --title "<title>" \
  --description "$(cat <<'EOF'
<description>
EOF
)"
```

**GitHub:**
```bash
gh pr create \
  --head "${BRANCH}" \
  --base "${DEFAULT_BRANCH}" \
  --title "<title>" \
  --body "$(cat <<'EOF'
<description>
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

Re-read ALL commits on the branch, not just new ones. The description should reflect the branch as it stands now.

**GitLab:**
```bash
glab mr update ${MR_ID} \
  --title "<title>" \
  --description "$(cat <<'EOF'
<description>
EOF
)"
```

**GitHub:**
```bash
gh pr edit ${PR_ID} \
  --title "<title>" \
  --body "$(cat <<'EOF'
<description>
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
