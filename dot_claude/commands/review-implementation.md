# Review Implementation

Deep-dive review of the current branch: checks spec/plan compliance, implementation completeness, and code quality.

## Step 1: Gather Context

Run in parallel:

```bash
git branch --show-current
```

```bash
git log --oneline -10
```

```bash
git remote show origin | grep "HEAD branch" | sed 's/.*: //'
```

## Step 2: Find the Matching Plan

Extract 3–5 keywords from the branch name (split on `-`, `/`, `_`) and from the commit messages.

Search `~/.claude/plans/` for those keywords:

```bash
grep -ril "<keyword1>\|<keyword2>\|<keyword3>" ~/.claude/plans/
```

- If multiple files match, pick the one with the most keyword hits (run `grep -ic` per file to count)
- If no file matches, continue without a plan and note this in the review

## Step 3: Read the Plan

If a matching plan was found, read its full contents.

## Step 4: Get the Full Diff

```bash
git diff <default_branch>...HEAD
```

Also get a summary for orientation:

```bash
git diff <default_branch>...HEAD --stat
```

## Step 5: Run the Review

Use the `pr-review-toolkit:review-pr` agent with the following context:

- The full diff and stat summary from Step 4
- The plan content from Step 3 (if found)
- The commit history from Step 1

Instruct the agent to produce a structured report covering:

### a. Plan Compliance *(skip if no plan was found)*
- Were all items in the plan implemented?
- Anything promised but missing?
- Anything implemented differently than specified — intentional or accidental?

### b. Code Quality
- Bugs, logic errors, off-by-one errors
- Security vulnerabilities (injection, auth issues, secrets in code, etc.)
- Silent failures — swallowed errors, empty catch blocks, inappropriate fallbacks
- Type design issues — poor encapsulation, weak invariants

### c. Test Coverage
- Are new features and edge cases tested?
- Are there critical paths with no tests?
- Do tests actually exercise the code or just mock everything?

### d. Verdict
A short overall summary: **Pass**, **Pass with notes**, or **Needs work** — with the top 1–3 action items if any.

## Output Format

Present the report with clear section headers. Lead with the Verdict so the user sees the bottom line immediately, then the detailed findings.

If no plan was found, call that out at the top so the user can point you to one if needed.
