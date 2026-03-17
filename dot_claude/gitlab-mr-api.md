# GitLab MR Code Reviews via API

- **`glab api -f` can't do nested JSON** — use `curl -H "Content-Type: application/json" -d @payload.json` for endpoints requiring nested objects (e.g., `position` in draft notes)
- **Extract glab token for curl**: `glab auth status -t 2>&1 | grep 'Token found' | awk '{print $NF}'`
- **Draft notes (pending review)**: `POST projects/:id/merge_requests/:iid/draft_notes` with `position` object → user publishes via "Submit review" in UI
- **Inline code suggestions**: Use `` ```suggestion:-N+M `` in note body (`-N` = lines above, `+M` = lines below to replace). Requires `position.new_line` to be set.
- **JSON payloads with bash code**: Use Python (`json.dump`) to a temp file to avoid multi-layer shell escaping
- **Verify remote file paths**: MR diff versions may show different paths than local — check via `projects/:id/merge_requests/:iid/versions`
- **Posting review comments — always use draft notes**: use `~/.claude/bin/gitlab-post-review-note.sh <project> <mr_iid> <note_file> [repo_file_path] [new_line]` — never post directly to `/notes`. Script auto-fetches diff SHAs for inline comments, posts to `/draft_notes` so comments stay pending until you click "Submit review" in the GitLab UI. Write comment text to a temp file first to avoid all shell quoting/backtick issues.
