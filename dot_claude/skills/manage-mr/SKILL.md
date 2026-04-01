---
name: manage-mr
description: Create, update, or manage merge/pull requests (GitHub, GitLab, Codeberg, Gitea)
user-invocable: true
argument-hint: "[create|update|merge|close]"
---

# Manage Merge/Pull Request

Create, update, or manage merge requests (GitLab) and pull requests (GitHub, Codeberg, Gitea).

## Prerequisites

Detect the platform from the remote URL - do NOT ask the user:

```bash
git remote get-url origin
```

| Remote contains | Platform | CLI | Term |
|-----------------|----------|-----|------|
| `github.com` | GitHub | `gh` | PR |
| `codeberg.org` | Codeberg | `berg` | PR |
| `gitlab` (incl. self-hosted) | GitLab | `glab` | MR |
| Anything else | Gitea (self-hosted) | `tea` | PR |

Verify the CLI is authenticated:

- GitHub: `gh auth status`
- Codeberg: `berg auth list`
- GitLab: `glab auth status`
- Gitea: `tea logins list`

If the token is expired, ask the user to re-authenticate (`gh auth login` / `berg auth login` / `glab auth login` / `tea login add`).

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

Check if a PR/MR already exists:

- GitLab: `glab mr list --source-branch "${BRANCH}"`
- GitHub: `gh pr list --head "${BRANCH}"`
- Codeberg: `berg pull list --output-mode json` (filter output by source branch)
- Gitea: `tea pulls list --state open --output json` (filter output by head branch)

If updating, also fetch the existing description:

- GitHub: `gh pr view --json title,body`
- GitLab: `glab mr view --output json`
- Codeberg: `berg pull view <number> --output-mode json`
- Gitea: `tea pulls <number> --output json`

Try to detect a linked issue from the branch name (e.g. `AI-123/feature-name` or `42-feature-name`). If found, fetch it:

- GitHub: `gh issue view <number> --json title,body`
- GitLab: `glab issue view <number>`
- Codeberg: `berg issue view <number> --output-mode json`
- Gitea: `tea issues <number> --output json`

## Step 2: Determine Action

| Condition | Action |
|-----------|--------|
| No existing PR/MR | **Create** |
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

**Codeberg:**
```bash
berg pull create \
  --source-branch "${BRANCH}" \
  --target-branch "${DEFAULT_BRANCH}" \
  --title "<TITLE from agent>" \
  --description "$(cat <<'EOF'
<DESCRIPTION from agent>
EOF
)"
```

**Gitea:**
```bash
tea pulls create \
  --head "${BRANCH}" \
  --base "${DEFAULT_BRANCH}" \
  --title "<TITLE from agent>" \
  --description "$(cat <<'EOF'
<DESCRIPTION from agent>
EOF
)"
```

Optional flags (ask user if relevant):

| Intent | GitLab | GitHub | Codeberg | Gitea |
|--------|--------|--------|----------|-------|
| Draft | `--draft` | `--draft` | (not supported) | (not supported) |
| Assign to self | `--assignee @me` | `--assignee @me` | `--assignees <user>` | `--assignees <user>` |
| Add labels | `--label X` | `--label X` | `--labels X` | `--labels X` |
| Add reviewer | `--reviewer X` | `--reviewer X` | (not in CLI) | (not in CLI) |
| Delete branch on merge | `--remove-source-branch` | `--delete-branch` | (not in CLI) | (not in CLI) |

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

**Codeberg:** (`berg pull edit` is interactive-only — use the API via curl)
```bash
REPO=$(git remote get-url origin | sed 's|.*codeberg.org[:/]||;s|\.git$||')
BERG_TOKEN=$(berg auth list --output-mode json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['token'])" 2>/dev/null)
curl -s -X PATCH "https://codeberg.org/api/v1/repos/${REPO}/pulls/${PR_ID}" \
  -H "Authorization: token ${BERG_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"title\": \"<TITLE>\", \"body\": \"<DESCRIPTION>\"}"
```

**Gitea:** (use `tea api`)
```bash
OWNER=$(git remote get-url origin | sed 's|.*[:/]\([^/]*\)/[^/]*\.git|\1|;s|.*[:/]\([^/]*\)/[^/]*$|\1|')
REPO_NAME=$(basename "$(git remote get-url origin)" .git)
tea api -X PATCH "repos/${OWNER}/${REPO_NAME}/pulls/${PR_ID}" \
  -f title="<TITLE from agent>" \
  -f body="<DESCRIPTION from agent>"
```

### Merge

Use the `AskUserQuestion` tool to ask: "Merge this PR/MR? Verify the pipeline is green and changes are tested." with options: "Yes, merge now", "Cancel"

**GitLab:**
```bash
glab mr merge ${MR_ID} --squash --remove-source-branch
```

**GitHub:**
```bash
gh pr merge ${PR_ID} --squash --delete-branch
```

**Codeberg:** (no CLI merge — use Forgejo API)
```bash
REPO=$(git remote get-url origin | sed 's|.*codeberg.org[:/]||;s|\.git$||')
BERG_TOKEN=$(berg auth list --output-mode json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['token'])" 2>/dev/null)
curl -s -X POST "https://codeberg.org/api/v1/repos/${REPO}/pulls/${PR_ID}/merge" \
  -H "Authorization: token ${BERG_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"Do":"squash","delete_branch_after_merge":true}'
```

**Gitea:** (use `tea api`)
```bash
OWNER=$(git remote get-url origin | sed 's|.*[:/]\([^/]*\)/[^/]*\.git|\1|;s|.*[:/]\([^/]*\)/[^/]*$|\1|')
REPO_NAME=$(basename "$(git remote get-url origin)" .git)
tea api -X POST "repos/${OWNER}/${REPO_NAME}/pulls/${PR_ID}/merge" \
  -f Do=squash \
  -F delete_branch_after_merge=true
```

### Close

- **GitLab:** `glab mr close ${MR_ID}`
- **GitHub:** `gh pr close ${PR_ID}`
- **Codeberg:** `berg pull edit` (interactive) or API: `curl -X PATCH .../pulls/${PR_ID} -d '{"state":"closed"}'`
- **Gitea:** `tea pulls close ${PR_ID}`

## Step 5: Confirm

Show the URL so the user can verify in the browser:

- GitLab: `glab mr view ${MR_ID} --web`
- GitHub: `gh pr view ${PR_ID} --web`
- Codeberg: `berg pull view ${PR_ID}` (copy URL from output)
- Gitea: `tea pulls ${PR_ID}` (copy URL from output) or `tea open`

## Tips

- **Push first**: Ensure the branch is pushed before creating (`git push -u origin ${BRANCH}`)
- **Rebase if behind**: If the branch is behind target, suggest rebasing first
- **Draft for WIP**: Use `--draft` to avoid premature reviews (GitHub/GitLab only)
- **Stacked PRs**: If depending on another branch, set target accordingly
