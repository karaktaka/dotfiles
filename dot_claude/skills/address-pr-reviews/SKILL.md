---
name: address-pr-reviews
description: Use this skill when the user wants to address, fix, or work through PR/MR review comments. Triggers on phrases like "address review comments", "fix review findings", "work through PR comments", "resolve review", "handle MR feedback", or when a PR/MR number is mentioned alongside requests to fix reviewer feedback.
version: 1.0.0
---

# Address PR/MR Review Comments

Work through all open review comments on the current PR/MR, fix what can be fixed, and properly resolve or escalate each finding.

## Step 1 — Identify the PR/MR

Detect the platform and PR/MR automatically:

```bash
# Get current branch
git branch --show-current

# Detect platform from remote
git remote -v
```

- **GitHub** (`github.com` in remote): use `gh`
- **GitLab** (any other host, incl. `gitlab.*`): use `glab`

If the user provided a PR/MR number or URL, use that directly. Otherwise, find the open PR/MR for the current branch.

```bash
# GitHub
gh pr view --json number,title,url,reviewDecision

# GitLab
glab mr view --output json
```

## Step 2 — Fetch All Open Review Threads

### GitHub — Use GraphQL for thread resolution state

```bash
# Get owner/repo from remote
REPO=$(git remote get-url origin | sed 's|.*github.com[:/]||;s|\.git$||')
PR_NUMBER=<number>

gh api graphql -f query='
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $number) {
        reviewThreads(first: 100) {
          nodes {
            id
            isResolved
            isOutdated
            comments(first: 10) {
              nodes {
                id
                body
                author { login }
                path
                line
                url
              }
            }
          }
        }
      }
    }
  }
' -F owner=<owner> -F repo=<repo> -F number=$PR_NUMBER
```

Filter to threads where `isResolved: false` and `isOutdated: false`.

### GitLab — Use discussions API

```bash
PROJECT_ID=$(glab api projects/:fullpath | jq '.id')
MR_IID=<iid>

glab api projects/$PROJECT_ID/merge_requests/$MR_IID/discussions \
  | jq '[.[] | select(.notes[0].resolvable == true and .notes[0].resolved == false)]'
```

## Step 3 — Categorize Each Finding

For each unresolved thread, classify the reviewer:

| Category | Signals |
|----------|---------|
| **CodeRabbit AI** | author login contains `coderabbit`, `coderabbitai`, or body contains `<!-- by coderabbit -->` |
| **Other AI bot** | login ends in `[bot]` or `_bot`, or is a known review bot |
| **Human** | everything else |

For **CodeRabbit comments**, extract the AI agent prompt if present — it appears in a collapsible `<details>` block with heading "🤖 Prompt for AI Agents" or similar. If found, use that prompt verbatim as guidance for fixing the issue.

## Step 4 — Triage Each Finding

For each unresolved thread, evaluate the finding:

### Classification

| Outcome | Criteria |
|---------|----------|
| **Fixable** | Clear, contained change; no design decisions required |
| **Not fixable** | False positive, stale/outdated context, or the code is correct as-is |
| **Out of scope / needs bigger refactor** | Requires architectural change, touches many files, or is a larger initiative |

### Decision tree

```
Is the finding valid?
├── No (false positive / already correct)
│   ├── AI review  → acknowledge and resolve directly
│   └── Human      → explain to user, ask if they want a reply posted
│
├── Yes, small fix
│   ├── Fix the code
│   ├── AI review  → resolve thread after fix
│   └── Human      → show fix, ask user "Should I reply with the fix and resolve?"
│
└── Yes, but out of scope / needs bigger refactor
    → Ask user how to proceed (see Step 6)
```

## Step 5 — Apply Fixes

For each **fixable** finding:

1. Read the referenced file(s) and understand the context
2. Apply the minimal fix that addresses the comment — do not refactor unrelated code
3. If CodeRabbit provided an AI agent prompt, follow it as additional guidance
4. Note which thread IDs correspond to which fixes (for resolution in Step 7)

For **not fixable** findings on AI reviews:
- Compose a brief reply explaining why the finding doesn't apply (e.g., "This is intentional — the value is validated upstream at [location]")
- Mark for resolution

## Step 6 — Out-of-Scope Findings

**Always pause and ask the user** before proceeding with any finding that requires a bigger refactor or is architecturally significant.

Present the finding clearly:

> **⚠ Out-of-scope finding** in thread [link]:
> "[brief summary of what the reviewer flagged]"
>
> This would require [explanation of scope]. Options:
> 1. Create a tracking issue and resolve the thread with a reference to it
> 2. Leave the thread open for now
> 3. Address it in this PR (I can help scope it)
>
> **What would you like to do?**

If the user chooses to create an issue, create it with:
```bash
# GitHub
gh issue create --title "[Refactor] <finding summary>" \
  --body "Flagged during review of PR #<number>.\n\n## Finding\n<finding detail>\n\n## Source\n<thread URL>"

# GitLab
glab issue create --title "[Refactor] <finding summary>" \
  --description "Flagged during review of MR !<iid>.\n\n## Finding\n<finding detail>\n\n## Source\n<thread URL>"
```

Then reply to the thread with the issue link and resolve it.

> **Note**: Even if a finding seems trivial, always offer to create a tracking issue. Small findings often represent future tech debt.

## Step 7 — Resolve Threads

### Rules

| Reviewer type | Resolution behavior |
|---------------|---------------------|
| AI review (fixed) | Resolve automatically after fix |
| AI review (not fixable / false positive) | Post explanation, then resolve |
| Human review (fixed) | **Ask user**: "Should I post the fix summary and resolve this thread?" |
| Human review (false positive) | **Ask user**: "Should I reply explaining why this doesn't apply and resolve?" |
| Out of scope (issue created) | Resolve with issue link after user confirms |
| Out of scope (deferred) | Leave open |

### GitHub — Resolve via GraphQL

```bash
gh api graphql -f query='
  mutation($threadId: ID!) {
    resolveReviewThread(input: {threadId: $threadId}) {
      thread { id isResolved }
    }
  }
' -F threadId="<THREAD_ID>"
```

### GitHub — Post reply before resolving

```bash
gh api repos/{owner}/{repo}/pulls/{pr}/comments/{comment_id}/replies \
  -f body="<reply text>"
```

### GitLab — Resolve discussion

```bash
glab api -X PUT "projects/$PROJECT_ID/merge_requests/$MR_IID/discussions/$DISCUSSION_ID" \
  -f resolved=true
```

### GitLab — Post reply

```bash
glab api -X POST "projects/$PROJECT_ID/merge_requests/$MR_IID/discussions/$DISCUSSION_ID/notes" \
  -f body="<reply text>"
```

## Step 8 — Final Status

After all threads are processed, post a summary comment on the PR/MR:

```
## Review addressed ✓

All open review threads have been processed:

- **Fixed**: N findings — [brief list]
- **Acknowledged / false positive**: N findings — [brief list]
- **Deferred to issue**: N findings — [issue links]
- **Awaiting author decision**: N findings (human reviewer threads)

🤖 Addressed with [Claude Code](https://claude.ai/code)
```

If there are still human-reviewer threads pending user decisions, do **not** post this summary yet — wait until the user has responded to all outstanding questions.

## Edge Cases

- **Outdated threads** (`isOutdated: true` on GitHub): skip unless the user explicitly asks to address them
- **Draft PRs**: proceed normally unless the user says otherwise
- **Threads with multiple comments** (discussions): read the full thread for context before triaging
- **CodeRabbit suggestion blocks** (`suggestion` code fences): apply them directly as code changes if they're clearly correct
- **Threads already resolved by someone else**: skip

## Platform Detection Quick Reference

```bash
# Remote contains github.com → GitHub
git remote get-url origin | grep -q 'github.com' && echo github || echo gitlab
```

For GitLab self-hosted (e.g., `gitlab.example.com`), all `glab` commands work the same way — `glab` auto-detects the host from the git remote.
