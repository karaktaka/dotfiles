#!/bin/bash
set -euo pipefail

# gitlab-post-review-note.sh — post or update a pending (draft) review comment on a KN GitLab MR
#
# Comments are posted as draft notes: only visible to you until you click
# "Submit review" in the GitLab UI. Never published automatically.
#
# Usage:
#   General comment:
#     gitlab-post-review-note.sh <project> <mr_iid> <note_file>
#
#   Inline diff comment:
#     gitlab-post-review-note.sh <project> <mr_iid> <note_file> <repo_file_path> <new_line>
#
#   Update existing draft note (text only, position unchanged):
#     gitlab-post-review-note.sh --update <draft_note_id> <project> <mr_iid> <note_file>
#
# Arguments:
#   project        Numeric project ID (e.g. 1566) or URL-encoded path
#                  (e.g. datascience%2Fdatascience)
#   mr_iid         MR number
#   note_file      Path to a file containing the comment text
#   repo_file_path (inline only) file path within the repo as shown in the diff
#   new_line       (inline only) line number in the new (right-hand) file

GITLAB_API="https://gitlab.example.com/api/v4"

UPDATE_ID=""
if [[ "${1:-}" == "--update" ]]; then
  UPDATE_ID="$2"
  shift 2
fi

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 [--update <draft_note_id>] <project> <mr_iid> <note_file> [repo_file_path] [new_line]" >&2
  exit 1
fi

PROJECT="$1"
MR_IID="$2"
NOTE_FILE="$3"
REPO_FILE="${4:-}"
NEW_LINE="${5:-}"

TOKEN=$(glab auth status -t 2>&1 | grep 'Token found' | awk '{print $NF}')
if [[ -z "$TOKEN" ]]; then
  echo "ERROR: Could not extract glab token. Run 'glab auth login' first." >&2
  exit 1
fi

TMPJSON=$(mktemp /tmp/gitlab-draft-note-XXXXXX.json)
trap 'rm -f "$TMPJSON"' EXIT

if [[ -n "$UPDATE_ID" ]]; then
  # Update mode: fetch existing note to preserve its position, then PUT with new text
  echo "Fetching existing draft note ${UPDATE_ID} to preserve position..."
  EXISTING=$(curl -sS --fail -H "PRIVATE-TOKEN: $TOKEN" \
    "$GITLAB_API/projects/${PROJECT}/merge_requests/${MR_IID}/draft_notes/${UPDATE_ID}")

  TMPEXISTING=$(mktemp /tmp/gitlab-draft-existing-XXXXXX.json)
  echo "$EXISTING" > "$TMPEXISTING"

  python3 - "$NOTE_FILE" "$TMPEXISTING" "$TMPJSON" <<'PYEOF'
import json, sys
note_file, existing_file, out_file = sys.argv[1:]
note = open(note_file).read()
existing = json.load(open(existing_file))
payload = {"note": note}
pos = existing.get("position")
if pos and pos.get("base_sha"):
    payload["position"] = pos
json.dump(payload, open(out_file, "w"), ensure_ascii=False)
PYEOF

  rm -f "$TMPEXISTING"

  HTTP_CODE=$(curl -sS -o /dev/null -w "%{http_code}" \
    -X PUT \
    -H "PRIVATE-TOKEN: $TOKEN" \
    -H "Content-Type: application/json" \
    -d @"$TMPJSON" \
    "$GITLAB_API/projects/${PROJECT}/merge_requests/${MR_IID}/draft_notes/${UPDATE_ID}")

  if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo "Draft note updated (HTTP $HTTP_CODE)"
    echo "Go to the MR and click 'Submit review' to publish."
  else
    echo "ERROR: Failed to update draft note (HTTP $HTTP_CODE)" >&2
    exit 1
  fi

elif [[ -n "$REPO_FILE" && -n "$NEW_LINE" ]]; then
  # Inline comment: fetch diff version SHAs and POST with position
  echo "Fetching diff version SHAs for inline comment..."
  VERSIONS=$(curl -sS --fail -H "PRIVATE-TOKEN: $TOKEN" \
    "$GITLAB_API/projects/${PROJECT}/merge_requests/${MR_IID}/versions")
  BASE_SHA=$(echo "$VERSIONS" | jq -r '.[0].base_commit_sha')
  START_SHA=$(echo "$VERSIONS" | jq -r '.[0].start_commit_sha')
  HEAD_SHA=$(echo "$VERSIONS" | jq -r '.[0].head_commit_sha')
  echo "  base=$BASE_SHA"
  echo "  head=$HEAD_SHA"

  python3 - "$NOTE_FILE" "$BASE_SHA" "$START_SHA" "$HEAD_SHA" "$REPO_FILE" "$NEW_LINE" "$TMPJSON" <<'PYEOF'
import json, sys
note_file, base_sha, start_sha, head_sha, repo_file, new_line, out_file = sys.argv[1:]
note = open(note_file).read()
payload = {
    "note": note,
    "position": {
        "position_type": "text",
        "base_sha": base_sha,
        "start_sha": start_sha,
        "head_sha": head_sha,
        "new_path": repo_file,
        "new_line": int(new_line),
    },
}
json.dump(payload, open(out_file, "w"), ensure_ascii=False)
PYEOF

  HTTP_CODE=$(curl -sS -o /dev/null -w "%{http_code}" \
    -X POST \
    -H "PRIVATE-TOKEN: $TOKEN" \
    -H "Content-Type: application/json" \
    -d @"$TMPJSON" \
    "$GITLAB_API/projects/${PROJECT}/merge_requests/${MR_IID}/draft_notes")

  if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo "Draft note posted (HTTP $HTTP_CODE)"
    echo "Go to the MR and click 'Submit review' to publish."
  else
    echo "ERROR: Failed to post draft note (HTTP $HTTP_CODE)" >&2
    exit 1
  fi

else
  # General comment: POST without position
  python3 - "$NOTE_FILE" "$TMPJSON" <<'PYEOF'
import json, sys
note_file, out_file = sys.argv[1:]
note = open(note_file).read()
json.dump({"note": note}, open(out_file, "w"), ensure_ascii=False)
PYEOF

  HTTP_CODE=$(curl -sS -o /dev/null -w "%{http_code}" \
    -X POST \
    -H "PRIVATE-TOKEN: $TOKEN" \
    -H "Content-Type: application/json" \
    -d @"$TMPJSON" \
    "$GITLAB_API/projects/${PROJECT}/merge_requests/${MR_IID}/draft_notes")

  if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    echo "Draft note posted (HTTP $HTTP_CODE)"
    echo "Go to the MR and click 'Submit review' to publish."
  else
    echo "ERROR: Failed to post draft note (HTTP $HTTP_CODE)" >&2
    exit 1
  fi
fi
