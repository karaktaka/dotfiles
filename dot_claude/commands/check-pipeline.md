# Check GitLab Pipeline Status

Check the GitLab CI pipeline status for the current branch.

## Prerequisites Check

First, verify that `glab` (GitLab CLI) is installed:

```bash
glab --version
```

If `glab` is not installed, ask the user:
- "The `glab` CLI is not installed. Would you like me to provide manual steps to check the pipeline instead?"

If `glab` is installed, test authentication:

```bash
glab auth status
```

If the token is expired (401 error or "Token is expired" message), ask the user:
- "Your GitLab token has expired. Please run `glab auth login` to refresh it, then ask me to check again. Alternatively, I can provide manual steps."

## Pipeline Check Process

### Step 1: Determine Project Path

Get the GitLab project path from the git remote:

```bash
git remote get-url origin | sed -E 's/.*gitlab[^\/]*[:\/]([^\.]+)(\.git)?/\1/' | sed 's/\//%2F/g'
```

### Step 2: Get Recent Pipelines

List recent pipelines for the current branch:

```bash
BRANCH=$(git branch --show-current)
PROJECT_PATH=$(git remote get-url origin | sed -E 's/.*gitlab[^\/]*[:\/]([^\.]+)(\.git)?/\1/' | sed 's/\//%2F/g')
glab api "projects/${PROJECT_PATH}/pipelines?ref=${BRANCH}&per_page=5" | jq -r '.[] | "\(.id): \(.status) (\(.source))"'
```

### Step 3: Handle Skipped Pipelines

**Important:** Pipelines may show as "skipped" due to automated image bump commits. These commits push version updates back to the repository and trigger pipelines that are intentionally skipped to prevent infinite loops.

If the latest pipeline is skipped:
1. Look for the most recent pipeline with status other than "skipped"
2. That pipeline contains the actual build results

### Step 4: Check Pipeline Details

For the relevant pipeline (not skipped), check job statuses:

```bash
PIPELINE_ID=<id-from-step-2>
glab api "projects/${PROJECT_PATH}/pipelines/${PIPELINE_ID}" | jq -r '{status: .status, web_url: .web_url}'
```

### Step 5: Check for Failures or Warnings

List any failed or problematic jobs:

```bash
glab api "projects/${PROJECT_PATH}/pipelines/${PIPELINE_ID}/jobs?per_page=100" | jq -r '.[] | select(.status == "failed") | "\(.name): \(.status) (allow_failure: \(.allow_failure))"'
```

Get job counts by status:

```bash
glab api "projects/${PROJECT_PATH}/pipelines/${PIPELINE_ID}/jobs?per_page=100" | jq -r 'group_by(.status) | .[] | "\(.[0].status): \(length) jobs"'
```

## Manual Steps (if glab unavailable)

If the user cannot use `glab`, provide these manual steps:

1. **Get the branch name:**
   ```bash
   git branch --show-current
   ```

2. **Get the GitLab project URL:**
   ```bash
   git remote get-url origin
   ```

3. **Open GitLab in browser:**
   Navigate to: `<project-url>/-/pipelines?ref=<branch-name>`
   (URL-encode the branch name: replace `/` with `%2F`)

4. **Find the correct pipeline:**
   - Look for pipelines with status other than "skipped"
   - The most recent non-skipped pipeline has the actual results
   - "Skipped" pipelines are from automated image bump commits

5. **Check pipeline details:**
   - Click on the pipeline to see all jobs
   - Jobs with orange warning icons failed but have `allow_failure: true`
   - Jobs with red X icons are actual failures

## Interpreting Results

| Pipeline Status | Meaning |
|-----------------|---------|
| success | All required jobs passed |
| success (with warnings) | Passed, but some `allow_failure` jobs failed |
| failed | One or more required jobs failed |
| skipped | Pipeline was skipped (check previous pipeline) |
| running | Pipeline is still in progress |
