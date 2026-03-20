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

## Step 2 — Discover & Assess Scope

Before classifying scope, **actively explore the codebase** using Agents and tools:

- Use the `Explore` or `Plan` subagent (via the Agent tool) to discover relevant files, understand architecture, trace dependencies, and surface non-obvious impacts — especially for unfamiliar areas.
- Use Agents in parallel where independent discovery tasks exist (e.g. "find all callers of X" + "find related tests" simultaneously).
- Do not rely solely on the user's description — verify against actual code.

Then classify the task:

| Level | Signals |
|-------|---------|
| **Small** | Single file, clear fix, no design decisions, low risk |
| **Medium** | 2–5 files, some design tradeoffs, moderate risk |
| **Large** | Cross-cutting, architectural changes, many files, high risk, or unclear dependencies |

Also note:
- **Reversibility**: Is this easy to undo, or destructive/hard to roll back?
- **Blast radius**: How many systems/people are affected?
- **Ambiguity**: Are there design or tradeoff decisions Claude shouldn't make unilaterally?

## Step 3 — Enter Plan Mode

**Always call `EnterPlanMode`** before presenting the plan, regardless of scope size. Label the scope clearly at the top of the plan:

> **Scope: Small / Medium / Large** — waiting for approval before proceeding

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

## Step 6 — Post-Implementation Verification (always)

After implementation is complete, **always** run a structured verification pass before declaring done. Use the `Explore` or `code-reviewer` subagent (via the Agent tool) to deeply scan the written code.

Check against each point in the approved plan:

| Check | What to verify |
|-------|----------------|
| **Plan compliance** | Every item in "Files to change" and "Approach" was actually implemented — nothing skipped or half-done |
| **Completeness** | No features, cases, or requirements from the plan are missing |
| **Correctness** | Logic is sound; no obvious bugs, off-by-ones, or broken edge cases |
| **Code reuse** | No duplication of existing utilities, helpers, or patterns already in the codebase |
| **Error handling** | Failures surface correctly; no silent swallows or missing boundary checks |
| **Out-of-scope drift** | Nothing outside the agreed plan was changed unilaterally |

Present a brief **Verification Report** summarising:
- What was verified ✓
- Any gaps or issues found, with severity (blocking / minor / note)
- Whether the implementation matches the plan exactly, or if deviations need the user's attention

If blocking issues are found, fix them before marking the task done. Surface minor issues and notes to the user and let them decide.
