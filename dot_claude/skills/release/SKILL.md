---
name: release
description: Use this skill when the user wants to cut, draft, or publish a release. Triggers on phrases like "draft a release", "cut a release", "new release", "tag a release", "create a release", or "release v<version>".
version: 1.0.0
---

# Draft & Publish a Release

Analyse commits since the last tag, suggest the next version, build a changelog, tag the commit, and create a draft GitHub release.

## Step 1 — Find the last tag and commits since it

```bash
# Most recent tag
git tag --sort=-version:refname | head -1

# Commits since that tag
git log --oneline <last-tag>..HEAD
```

If there are no commits since the last tag, stop and tell the user there is nothing to release.

## Step 2 — Suggest the next version

Parse the conventional commit prefixes from the commit list:

| Condition | Bump |
|-----------|------|
| Any `feat:` or `feat(*):`  commit | minor (`x.Y.0`) |
| Only `fix:`, `perf:`, `refactor:`, `chore:`, `docs:`, `config:` | patch (`x.y.Z`) |
| Breaking change (`BREAKING CHANGE` in body, or `!` after type) | major (`X.0.0`) |

For 0.x.x projects, minor bumps stay minor (do not promote to major on `feat`).

If the user already supplied a version (e.g. `/release v0.8.0` or "release 0.8.0"), skip the suggestion and use that version directly.

Present the suggested version and ask for confirmation before proceeding:

> Suggested version: **vX.Y.Z** (minor bump — N new features since vA.B.C)
> Proceed with this version, or enter a different one?

Use the `AskUserQuestion` tool with options: "Yes, use vX.Y.Z", "Enter a different version".

## Step 3 — Check CI status

```bash
gh run list --branch main --limit 5 --json status,conclusion,name,headSha
```

If the most recent run on `main` is not `completed`/`success`, warn the user:

> CI is not green on main (status: <status>). Tagging now will build from a potentially broken commit.

Use `AskUserQuestion`: "Proceed anyway, or wait for CI?" with options: "Proceed anyway", "Cancel — I'll re-run after CI passes".

## Step 4 — Build the changelog

Group the commits since the last tag into sections. Only include sections that have entries. Omit `chore(deps)` bumps from the changelog body — they add noise. If there are many dependency bumps, add a single line "Dependencies updated" under a "Maintenance" section.

Standard section order:

1. **New Features** — `feat`
2. **Performance** — `perf`
3. **Fixes** — `fix`
4. **Refactor** — `refactor`
5. **Maintenance** — `chore`, `config`, `docs` (non-CLAUDE.md), `ci`

Format each entry as:
```
- <commit subject stripped of prefix and scope> (#PR)
```

Group entries within a section by module/scope if there are 3+ entries for the same scope (e.g. multiple `feat(wow):` entries under a **WoW** sub-heading within New Features).

Do not use emojis in the changelog.

## Step 5 — Tag the release

```bash
git tag -a v<version> -m "Release v<version>"
git push origin v<version>
```

## Step 6 — Create a draft GitHub release

Detect the repo from the git remote:

```bash
git remote get-url origin
```

Create the draft release via `gh`:

```bash
gh release create v<version> \
  --repo <owner>/<repo> \
  --title "v<version> — <short title>" \
  --draft \
  --notes "<changelog>"
```

The short title should be a brief summary of the most significant theme of the release (e.g. "Web Dashboard & WoW Crafting Board"). Derive it from the changelog — do not make it generic.

## Step 7 — Report back

Return the draft release URL to the user and note:

- CI workflows that will fire (`docker.yml`, `release-badge.yml` if applicable)
- That a badge-update PR will be opened automatically and needs to be merged
- That they can publish the draft release from the GitHub UI when ready
