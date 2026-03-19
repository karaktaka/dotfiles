---
name: scope-and-plan
description: Use when starting a new task or session to assess scope, determine if plan mode is needed, ask clarifying questions, and present a structured plan. Trigger at the start of any non-trivial request before writing code or making changes.
---

# Scope Assessment & Planning

Before writing any code or making changes, always assess the task first.

## Step 1 — Identify Missing Information

Before assessing scope, surface any blockers:

- Is the goal ambiguous or underspecified?
- Are there multiple valid interpretations?
- Is crucial context missing (which file, which environment, which behavior is expected)?

**If any blockers exist: ask first. Do not guess. Make the question impossible to miss — don't bury it.**

Only proceed to scope assessment once the goal is clear.

## Step 2 — Assess Scope & Complexity

Classify the task:

| Level | Signals |
|-------|---------|
| **Small** | Single file, clear fix, no design decisions, low risk |
| **Medium** | 2–5 files, some design tradeoffs, moderate risk |
| **Large** | Cross-cutting, architectural changes, many files, high risk, or unclear dependencies |

Also note:
- **Reversibility**: Is this easy to undo, or destructive/hard to roll back?
- **Blast radius**: How many systems/people are affected?
- **Ambiguity**: Are there design or tradeoff decisions Claude shouldn't make unilaterally?

## Step 3 — Decide: Plan Mode or Not?

| Condition | Action |
|-----------|--------|
| Small + clear | Present a brief inline plan, then wait for approval |
| Medium or uncertain | Present a detailed inline plan, then wait for approval |
| Large or high-impact | Enter plan mode (`EnterPlanMode`), present full plan, wait for approval |

When entering plan mode, label the scope clearly at the top of the plan:
> **Scope: Large / High-impact** — requires approval before proceeding

## Step 4 — Present the Plan

Structure (scale detail to scope):

1. **Goal** — one sentence restating what we're doing and why
2. **Scope label** — Small / Medium / Large
3. **Files to change** — list the specific files and what changes in each
4. **Approach** — key design decisions or tradeoffs
5. **Out of scope** — what we're explicitly NOT doing (prevents scope creep)
6. **Open questions** (if any remain) — list them before presenting the plan

All steps apply regardless of scope. Scale the depth of detail to the task size, but never skip open questions if any exist.

## Step 5 — Wait for Approval (always)

For **all** tasks regardless of scope: use the `AskUserQuestion` tool to ask: "Ready to proceed with this plan?" with options: "Yes, proceed", "Modify the plan first", "Cancel" — do not begin implementation until the user explicitly approves.
