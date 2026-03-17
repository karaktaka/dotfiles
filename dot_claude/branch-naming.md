# Branch Naming Conventions

## When Working from an Issue

**Issue context takes priority over all other naming rules below.**

- GitHub/GitLab issues: `feature/<issue-number>-short-description` or `fix/<issue-number>-short-description`
- **KN (Jira)**: `<PROJECT>-<ticket_id>/short-description` — e.g. `AI-123/add-user-auth`. The `<PROJECT>-<id>/` prefix auto-links the branch to the Jira ticket.
- Always link the MR/PR back to the issue in its description, and cross-reference the MR from the issue.

## With Existing Changes

When there are uncommitted changes (and no issue context), derive the branch name from the changes:

- Analyze changed files and their content
- Format: `feature/<short-description>` or `fix/<short-description>`
- Examples: `feature/add-user-auth`, `fix/login-validation`

## Without Changes (Fun Names)

When creating a fresh branch with no changes, use movie-based names:

- Format: `<movie-reference>-<actor-reference>` (all lowercase, hyphens)
- Prefer movies from 2000 onwards, but classic widely-known films are acceptable
- Keep it short — max 3-4 words total

**Examples:**
- `inception-leo` (Inception, Leonardo DiCaprio)
- `matrix-keanu` (The Matrix, Keanu Reeves)
- `wick-reeves` (John Wick, Keanu Reeves)
- `interstellar-mcconaughey` (Interstellar)
- `joker-phoenix` (Joker, Joaquin Phoenix)
- `django-jamie` (Django Unchained, Jamie Foxx)
- `fury-road-tom` (Mad Max: Fury Road, Tom Hardy)
- `batman-bale` (The Dark Knight, Christian Bale)
- `gladiator-russell` (Gladiator, Russell Crowe)
- `lotr-viggo` (Lord of the Rings, Viggo Mortensen)

## General Rules

- No special characters except hyphens
- Keep under 30 characters when possible
- Memorable but professional enough for work
