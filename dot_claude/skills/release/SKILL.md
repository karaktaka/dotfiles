---
name: release
description: Use this skill when the user wants to cut, draft, or publish a release. Triggers on phrases like "draft a release", "cut a release", "new release", "tag a release", "create a release", or "release v<version>".
version: 1.2.0
---

# Draft & Publish a Release

Analyse commits since the last tag, suggest the next version, build a changelog, tag the commit, and create a draft release.

## Platform Detection

```bash
git remote get-url origin
```

| Remote contains | Platform | CLI |
|-----------------|----------|-----|
| `github.com` | GitHub | `gh` |
| `codeberg.org` | Codeberg | `berg` |
| `gitlab` | GitLab | `glab` |
| Anything else | Gitea | `tea` |

## Step 1 — Find the last tag and commits since it

```bash
# Most recent tag
git tag --sort=-version:refname | head -1

# Commits since that tag — full format for changelog agent
git log <last-tag>..HEAD --format="%H %s%n%b"

# Shortlog for version suggestion
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

## Step 3 — CI check and changelog in parallel

Once the version is confirmed, run both tasks simultaneously:

### Task A — CI status (run directly)

Check CI status using the platform CLI:

```bash
# GitHub
gh run list --branch main --limit 5 --json status,conclusion,name,headSha

# GitLab
glab ci list --branch main

# Codeberg / Gitea — use the API (Gitea REST structure for both)
# Codeberg:
REPO=$(git remote get-url origin | sed 's|.*codeberg.org[:/]||;s|\.git$||')
BERG_TOKEN=$(berg auth list --output-mode json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['token'])" 2>/dev/null)
curl -s "https://codeberg.org/api/v1/repos/${REPO}/commits/$(git rev-parse HEAD)/statuses" \
  -H "Authorization: token ${BERG_TOKEN}" | jq '.[0:5] | .[] | {state,context,description}'
# Gitea:
tea api "repos/{owner}/{repo}/commits/$(git rev-parse HEAD)/statuses" | jq '.[0:5] | .[] | {state,context,description}'
```

Hold the result — present it after Task B completes.

### Task B — Changelog agent (spawn via Agent tool, subagent_type: `general-purpose`)

Pass the full commit log and formatting rules below.

#### Changelog agent prompt

```
You are a changelog writer for a software release. Given the commit log below, produce a formatted changelog body and a short release title.

## Version being released
<vX.Y.Z>

## Previous tag
<last-tag>

## Commit log (since <last-tag>)
<paste full git log output>

## Formatting rules

### Sections (include only sections with entries, in this order)
1. **New Features** — `feat`
2. **Performance** — `perf`
3. **Fixes** — `fix`
4. **Refactor** — `refactor`
5. **Maintenance** — `chore`, `config`, `docs` (non-CLAUDE.md), `ci`

### Entry format
- <commit subject stripped of type prefix and scope> (#PR if present)

### Grouping
Within a section, group entries by scope if there are 3+ entries for the same scope
(e.g. multiple `feat(auth):` commits → **Auth** sub-heading within New Features).

### Noise filtering
- Omit `chore(deps)` bumps from the changelog body
- If there are many dependency bumps, add a single "Dependencies updated" under Maintenance
- Do not use emojis

### Short release title
Derive a brief (5–10 word) title from the most significant theme of the release.
Example: "Web Dashboard & WoW Crafting Board". Do NOT use a generic title.

## Output format

Return exactly two sections:

### CHANGELOG
<formatted changelog markdown>

### TITLE
<short release title>
```

Wait for both tasks to complete before proceeding.

## Step 4 — Handle CI warning if applicable

If the most recent run from Task A is not `completed`/`success`, warn the user:

> CI is not green on main (status: <status>). Tagging now will build from a potentially broken commit.

Use `AskUserQuestion`: "Proceed anyway, or wait for CI?" with options: "Proceed anyway", "Cancel — I'll re-run after CI passes".

If the user cancels, stop here.

## Step 5 — Tag the release

```bash
git tag -a v<version> -m "Release v<version>"
git push origin v<version>
```

## Step 6 — Create a draft release

Use the `CHANGELOG` and `TITLE` from the changelog agent. The repo is already known from platform detection.

**GitHub:**
```bash
gh release create v<version> \
  --repo <owner>/<repo> \
  --title "v<version> — <TITLE from agent>" \
  --draft \
  --notes "<CHANGELOG from agent>"
```

**GitLab:**
```bash
glab release create v<version> \
  --name "v<version> — <TITLE from agent>" \
  --notes "<CHANGELOG from agent>"
```

**Codeberg** (Forgejo API — `berg release create` is interactive only):
```bash
REPO=$(git remote get-url origin | sed 's|.*codeberg.org[:/]||;s|\.git$||')
BERG_TOKEN=$(berg auth list --output-mode json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d[0]['token'])" 2>/dev/null)
curl -s -X POST "https://codeberg.org/api/v1/repos/${REPO}/releases" \
  -H "Authorization: token ${BERG_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"tag_name\":\"v<version>\",\"name\":\"v<version> — <TITLE>\",\"body\":\"<CHANGELOG>\",\"draft\":true}"
```

**Gitea:**
```bash
tea releases create \
  --tag "v<version>" \
  --title "v<version> — <TITLE from agent>" \
  --note "<CHANGELOG from agent>" \
  --draft
```

## Step 7 — Report back

Return the draft release URL to the user and note:

- CI workflows that will fire (`docker.yml`, `release-badge.yml` if applicable)
- That a badge-update PR will be opened automatically and needs to be merged
- That they can publish the draft release from the GitHub UI when ready
