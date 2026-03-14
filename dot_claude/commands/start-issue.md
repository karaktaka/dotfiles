# Start Issue

Load a GitHub issue or GitLab issue/ticket, understand it fully, and ask clarifying questions before any planning or implementation begins.

**Issue reference:** $ARGUMENTS

## Step 1: Detect platform

```bash
git remote get-url origin
```

| Remote contains | Platform | CLI | Issue term |
|----------------|----------|-----|------------|
| `github.com` | GitHub | `gh` | Issue |
| Anything else | GitLab (self-hosted or `.com`) | `glab` | Issue |

If not in a git repo, fall back to the issue reference format to infer the platform (e.g. a GitHub URL).

## Step 2: Resolve the issue number

`$ARGUMENTS` may be:
- A plain number: `42`
- A GitHub/GitLab URL: extract the numeric ID from the path

## Step 3: Fetch the issue

**GitHub:**
```bash
gh issue view <number> --json number,title,body,labels,assignees,milestone,comments
```

**GitLab:**
```bash
glab issue view <number>
```

Read the full output including description and any existing comments.

## Step 4: Enter plan mode

Use the `EnterPlanMode` tool now — before proposing anything.

## Step 5: Summarise and ask clarifying questions

Present a structured summary of the issue:

- **What**: One-sentence description of the problem or feature
- **Why**: The motivation or business reason, if stated
- **Acceptance criteria**: What "done" looks like, extracted from the issue (or noted as missing)
- **Unknowns / ambiguities**: Anything unclear, underspecified, or that could be interpreted multiple ways

Then ask targeted clarifying questions. Focus on things that would materially change the implementation approach — not nitpicks. Examples of good questions:
- Scope: "Should this handle X edge case, or is that out of scope?"
- Constraints: "Is there a performance requirement, or just correctness?"
- Existing patterns: "Should this follow the existing Y pattern, or is a new approach preferred?"
- Dependencies: "Does this need to be backwards-compatible with Z?"

Do **not** start proposing a solution yet. Wait for the user's answers before forming a plan.
