---
name: address-pr-reviews
description: Use this skill when the user wants to address, fix, or work through PR/MR review comments. Triggers on phrases like "address review comments", "fix review findings", "work through PR comments", "resolve review", "handle MR feedback", or when a PR/MR number is mentioned alongside requests to fix reviewer feedback.
version: 1.0.0
---

# Address PR/MR Review Comments

Work through all open review comments on the current PR/MR, fix what can be fixed, and properly resolve or escalate each finding.

## Step 0 — Determine mode

**Read-only mode** — use when the user asks to "show", "list", or "summarise" review comments, or passes `--read-only`:
1. Execute Steps 1–3 only (identify PR/MR, fetch threads, categorise)
2. Present a summary table: reviewer name, file:line, brief description of feedback, category (human/AI/bot)
3. Use the `AskUserQuestion` tool to ask: "How would you like to proceed?" with options: "Walk me through each fix", "Apply all fixes automatically", "Leave as-is for now" — stop here, do **not** apply fixes, resolve threads, or post any comments without the user's choice

**Full mode** (default) — proceed through all steps below.

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

## Step 2b — Fetch Outside-Diff Comments (GitHub only)

GitHub cannot post inline comments on lines that fall outside the PR's changed diff. Reviewers (especially CodeRabbit) embed these as free-text findings inside the PR review body instead. They are **not** captured by the `reviewThreads` query in Step 2 and must be fetched separately.

```bash
gh api graphql -f query='
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $number) {
        reviews(first: 50) {
          nodes {
            author { login }
            body
            submittedAt
          }
        }
      }
    }
  }
' -F owner=<owner> -F repo=<repo> -F number=$PR_NUMBER
```

For each review body:
- Look for a collapsible section matching `⚠️ Outside diff range comments` or similar.
- Extract each finding: file path, line reference, severity, description, and any embedded AI agent prompt (in a `🤖 Prompt for AI Agents` `<details>` block).
- Treat these findings with the **same triage rules as inline threads** (Steps 3–7), but note they have **no thread ID to resolve** — instead, acknowledge them in the final status report.
- **Deduplicate**: CodeRabbit re-emits the same outside-diff finding in each re-review cycle. If the same finding appears in multiple review bodies, process it only once (use the most recent version).
- **Stale check**: Before acting on any outside-diff finding, verify the referenced code still has the issue — the finding may refer to an earlier commit that has since been updated.

For **CodeRabbit outside-diff findings** that are fixed: post a reply to the PR review (not possible via GitHub API — instead note the fix in the final CLI summary).
For **false positives**: note the reason in the final CLI summary.

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
│   └── Human      → explain; AskUserQuestion: "Post a reply explaining why this doesn't apply?"
│                    options: "Yes, post reply and resolve" / "No, leave open"
│
├── Yes, small fix
│   ├── Fix the code
│   ├── AI review  → resolve thread after fix
│   └── Human      → show fix; AskUserQuestion: "Reply with the fix and resolve this thread?"
│                    options: "Yes, reply and resolve" / "Apply fix only, skip reply" / "Skip"
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
- Post a brief reply **on the thread** explaining why the finding doesn't apply (e.g., "This is intentional — the value is validated upstream at [location]")
- Resolve the thread after posting the reply

For **not fixable** findings on human reviews where the user chose to leave the thread open:
- Do **not** post any PR-level comment — Step 8 handles surfacing these if needed

## Step 6 — Out-of-Scope Findings

**Always pause and ask the user** before proceeding with any finding that requires a bigger refactor or is architecturally significant.

Present the finding clearly:

> **⚠ Out-of-scope finding** in thread [link]:
> "[brief summary of what the reviewer flagged]"
>
> This would require [explanation of scope].

Use the `AskUserQuestion` tool to ask: "How would you like to handle this finding?" with options: "Create a tracking issue and resolve the thread", "Leave the thread open for now", "Address it in this PR"

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
| Human review (fixed) | Use `AskUserQuestion`: "Reply with fix summary and resolve this thread?" → "Yes, reply and resolve" / "Apply fix only, no reply" / "Skip" |
| Human review (false positive) | Use `AskUserQuestion`: "Reply explaining why this doesn't apply and resolve?" → "Yes, reply and resolve" / "No, leave open" |
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

**Do not post a PR/MR-level summary comment if all open threads were addressed** (fixed, resolved, or replied to with a reason). Simply report the outcome to the user in the CLI.

Only post a PR/MR-level comment if there are threads that could **not** be addressed and were left open — and only to explain those specific cases. Use `AskUserQuestion` first: "Some threads were left open. Post a comment explaining why?" with options: "Yes, post comment", "No, skip".

If posting, limit the comment to the unresolved threads only:

```
## Review partially addressed

The following threads were left open and require author attention:

- **[file:line or description]** — [reason it wasn't addressed, e.g. "out of scope — tracked in #123", "needs design decision", "awaiting clarification"]

All other threads have been resolved.

🤖 Addressed with [Claude Code](https://claude.ai/code)
```

If there are still human-reviewer threads pending user decisions, do **not** post this comment yet — wait until the user has responded to all outstanding questions.

## Edge Cases

- **Outdated threads** (`isOutdated: true` on GitHub): skip unless the user explicitly asks to address them
- **Draft PRs**: proceed normally unless the user says otherwise
- **Threads with multiple comments** (discussions): read the full thread for context before triaging
- **CodeRabbit suggestion blocks** (`suggestion` code fences): apply them directly as code changes if they're clearly correct
- **Threads already resolved by someone else**: skip
- **Outside-diff findings have no resolvable thread**: they cannot be resolved via the GraphQL mutation — acknowledge them in the final CLI status report instead of attempting to resolve them

## Platform Detection Quick Reference

```bash
# Remote contains github.com → GitHub
git remote get-url origin | grep -q 'github.com' && echo github || echo gitlab
```

For GitLab self-hosted (e.g., `gitlab.example.com`), all `glab` commands work the same way — `glab` auto-detects the host from the git remote.
