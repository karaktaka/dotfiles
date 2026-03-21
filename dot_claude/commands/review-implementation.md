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

Launch the following agents **in parallel**, passing each one the full diff, stat summary, commit history, and plan content (if found):

### Agent 1 — `pr-review-toolkit:code-reviewer`
Focus: bugs, logic errors, security vulnerabilities, code quality, and project conventions.
If a plan was found, also check plan compliance: were all items implemented? Anything missing or done differently than specified?

### Agent 2 — `pr-review-toolkit:pr-test-analyzer`
Focus: test coverage. Are new features and edge cases tested? Are there critical paths with no tests? Do tests actually exercise the code or just mock everything?

### Agent 3 — `pr-review-toolkit:silent-failure-hunter`
Focus: silent failures — swallowed errors, empty catch blocks, inappropriate fallbacks, missing error propagation.

### Agent 4 — `pr-review-toolkit:type-design-analyzer`
Focus: type design — poor encapsulation, weak invariants, types that fail to express their constraints.

Wait for all agents to complete, then consolidate their findings.

## Output Format

Present the report with clear section headers. Lead with the Verdict so the user sees the bottom line immediately, then the detailed findings.

If no plan was found, call that out at the top so the user can point you to one if needed.
