# Check Ticket Coverage

Verify that the current branch's MR fully implements the requirements in the associated Jira ticket.

## Step 1: Understand what this branch implements

Get the diff and commit context:

```bash
glab mr diff $(git branch --show-current) --raw
```

```bash
git log --oneline $(glab mr view --output json | jq -r '.targetBranch')..HEAD
```

## Step 2: Get the Jira ticket

Extract the ticket ID (e.g. `AI-1234`) from the branch name:

```bash
git branch --show-current
```

Use the `working-with-jira` skill to fetch the full ticket including acceptance criteria and description.

## Step 3: Compare

Check whether the MR fully implements the ticket requirements. For each requirement, mark it as:
- **Fully implemented** — code change clearly addresses it
- **Partially implemented** — addressed but incomplete or with caveats
- **Not implemented** — no corresponding change found
- **Out of scope** — deliberately excluded (note if this seems intentional)

Summarise your findings and flag anything that would block merge.
