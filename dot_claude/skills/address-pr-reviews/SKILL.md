---
name: address-pr-reviews
description: Use this skill when the user wants to address, fix, or work through PR/MR review comments. Triggers on phrases like "address review comments", "fix review findings", "work through PR comments", "resolve review", "handle MR feedback", or when a PR/MR number is mentioned alongside requests to fix reviewer feedback.
version: 1.1.0
---

# Address PR/MR Review Comments

Work through all open review comments on the current PR/MR, fix what can be fixed, and properly resolve or escalate each finding.

## Step 0 — Determine mode

**Read-only mode** — use when the user asks to "show", "list", or "summarise" review comments, or passes `--read-only`:
1. Execute Steps 1–3 only (identify PR/MR, fetch threads, triage agent)
2. Present the triage table returned by the agent: reviewer name, file:line, brief description, category (human/AI/bot), classification
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

Save: `PLATFORM`, `PR_NUMBER` (or `MR_IID`), `OWNER`, `REPO`, `PROJECT_ID` (GitLab), `WORKTREE_ROOT` (`git rev-parse --show-toplevel`).

## Step 2 — Fetch all threads and outside-diff comments in parallel

Run both fetches simultaneously — they are independent API calls.

### Fetch A — Open review threads

**GitHub:**
```bash
REPO=$(git remote get-url origin | sed 's|.*github.com[:/]||;s|\.git$||')

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

**GitLab:**
```bash
PROJECT_ID=$(glab api projects/:fullpath | jq '.id')

glab api projects/$PROJECT_ID/merge_requests/$MR_IID/discussions \
  | jq '[.[] | select(.notes[0].resolvable == true and .notes[0].resolved == false)]'
```

### Fetch B — Outside-diff comments (GitHub only)

GitHub cannot post inline comments on lines outside the PR's changed diff. Reviewers (especially CodeRabbit) embed these as free-text findings inside the PR review body instead.

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

Also fetch the current diff for context:
```bash
git diff <default_branch>...HEAD
```

## Step 3 — Triage agent

Spawn a **triage agent** (subagent_type: `general-purpose`) passing it:
- All raw thread data from Fetch A
- All review bodies from Fetch B
- The full diff
- The worktree root path

### Triage agent prompt template

```
You are a code review triage agent. Analyze the review threads and outside-diff findings below and return a structured triage table. Do not apply any fixes — analysis only.

## Context

Worktree root: <WORKTREE_ROOT>
Platform: <github|gitlab>
PR/MR: <number>

## Raw thread data

<paste full JSON from Fetch A>

## Review bodies (outside-diff comments)

<paste review body JSON from Fetch B>

## Diff

<paste git diff output>

## Your tasks

### 1. Categorize each reviewer
| Category | Signals |
|----------|---------|
| CodeRabbit AI | login contains `coderabbit`/`coderabbitai`, or body contains `<!-- by coderabbit -->` |
| Other AI bot | login ends in `[bot]` or `_bot` |
| Human | everything else |

### 2. Classify each finding
| Outcome | Criteria |
|---------|----------|
| Fixable | Clear, contained change; no design decisions required |
| Not fixable | False positive, stale/outdated, or code is correct as-is |
| Out of scope | Requires architectural change, touches many files, or is a larger initiative |

### 3. For CodeRabbit findings: extract the AI agent prompt if present
It appears in a `<details>` block with heading "🤖 Prompt for AI Agents" or similar. Return it verbatim.

### 4. For outside-diff findings: deduplicate and stale-check
- If the same finding appears in multiple review bodies, use only the most recent.
- Read the referenced file at the referenced line. If the code no longer has the issue, mark as stale/not-fixable.

### 5. Return a structured triage table

For each finding, return:
- Thread ID (or "outside-diff" if no thread)
- File path + line (repo-relative)
- Reviewer category
- Classification
- One-sentence summary of the finding
- If fixable: suggested fix approach (and extracted AI agent prompt if present)
- If not fixable: reason
- If out of scope: brief description of the refactor needed

Group: fixable first, then not-fixable, then out-of-scope.
```

Wait for the triage agent to return the full table before proceeding.

**In read-only mode**: present the triage table to the user and stop (see Step 0).

## Step 4 — Handle out-of-scope findings

For each finding classified as **out of scope**, pause and ask the user:

> **⚠ Out-of-scope finding** — [file:line]:
> "[summary from triage table]"
> This would require [agent's description of scope].

Use `AskUserQuestion`: "How would you like to handle this finding?" with options:
- "Create a tracking issue and resolve the thread"
- "Leave the thread open for now"
- "Address it in this PR"

If creating an issue:
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

## Step 5 — Fixer agent

Take all **fixable** findings from the triage table. Spawn a **fixer agent** (subagent_type: `general-purpose`) passing it the triage table (fixable items only), worktree root, and branch context.

### Fixer agent prompt template

```
You are a code-fix agent. Apply the fixes listed below. Do NOT refactor, reformat, or change anything outside the specific lines referenced in each finding. Do NOT add comments or docstrings unless the finding explicitly asks for them.

## Context

Worktree root: <WORKTREE_ROOT>
Branch: <BRANCH_NAME>
All file paths are relative to the worktree root.

## Findings to fix

<For each fixable finding from the triage table:>
### Finding <N> — <reviewer category> — <file:line>

Thread ID: <id or "outside-diff">
File: `<repo-relative path>`
Lines: <N>–<M>
Summary: <one-sentence description>
Fix approach: <from triage agent>
AI agent prompt (if present): <verbatim extracted prompt>

<repeat for all fixable findings>

## Instructions

1. Work through findings in order.
2. For each finding:
   a. Read the referenced file at the specified lines.
   b. Apply the minimal fix. If an AI agent prompt was provided, follow it as the primary guidance.
   c. Do not touch other lines.
3. Output a brief report after all fixes:
   - Finding number, file:line, one-line description of what was changed
   - Any finding you could NOT fix, with reason
4. Do not commit. Do not run tests. Do not touch files not listed above.
```

Wait for the fixer agent to return its report before proceeding.

## Step 6 — Resolve threads

Using the fixer agent's report and the triage table, resolve threads according to these rules:

| Reviewer type | Resolution behavior |
|---------------|---------------------|
| AI review (fixed) | Resolve automatically |
| AI review (not fixable / false positive) | Post explanation from triage table, then resolve |
| Human review (fixed) | `AskUserQuestion`: "Reply with fix summary and resolve this thread?" → "Yes, reply and resolve" / "Apply fix only, no reply" / "Skip" |
| Human review (false positive) | `AskUserQuestion`: "Reply explaining why this doesn't apply and resolve?" → "Yes, reply and resolve" / "No, leave open" |
| Out of scope (issue created) | Resolve with issue link |
| Out of scope (deferred) | Leave open |
| Fixer agent could not fix | Treat as out-of-scope — ask user |

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

## Step 7 — Final Status

**Do not post a PR/MR-level summary comment if all open threads were addressed.** Simply report the outcome to the user in the CLI.

Only post a PR/MR-level comment if threads were left open. Use `AskUserQuestion` first: "Some threads were left open. Post a comment explaining why?" with options: "Yes, post comment", "No, skip".

If posting:
```
## Review partially addressed

The following threads were left open and require author attention:

- **[file:line or description]** — [reason: "out of scope — tracked in #123", "needs design decision", etc.]

All other threads have been resolved.

🤖 Addressed with [Claude Code](https://claude.ai/code)
```

If human-reviewer threads are still pending user decisions, do **not** post yet — wait for all outstanding `AskUserQuestion` responses.

> Changes are unstaged. Review with `git diff` before committing.

## Edge Cases

- **Outdated threads** (`isOutdated: true` on GitHub): skip unless the user explicitly asks to address them
- **Draft PRs**: proceed normally unless the user says otherwise
- **Threads with multiple comments** (discussions): pass the full thread to the triage agent — context matters
- **CodeRabbit suggestion blocks** (`suggestion` code fences): the fixer agent should apply them directly if clearly correct
- **Threads already resolved by someone else**: skip
- **Outside-diff findings**: no resolvable thread ID — acknowledge in the final CLI status report only

## Platform Detection Quick Reference

```bash
git remote get-url origin | grep -q 'github.com' && echo github || echo gitlab
```

For GitLab self-hosted (e.g., `gitlab.example.com`), all `glab` commands work the same — `glab` auto-detects the host from the git remote.
