#!/usr/bin/env bash
# Fetch GitHub issue activity for Slack status summaries.
# Dependencies: gh, jq
# Output: JSON to stdout

set -euo pipefail

REPO=""
SINCE_INPUT="friday"
AUTHOR=""
SINCE_ALIAS=""

usage() {
  cat <<'EOF'
Usage: fetch-issue-activity.sh [OPTIONS]

Options:
  --repo OWNER/REPO   Target repository (default: current repo via gh)
  --since DATE        Start date: YYYY-MM-DD, friday, monday, today, or N-days (default: friday)
  --author LOGIN      Filter timeline activity to a GitHub user (optional)
  -h, --help          Show this help

Output: JSON with completed and open issues since the given date.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO="${2:?--repo requires a value}"
      shift 2
      ;;
    --since)
      SINCE_INPUT="${2:?--since requires a value}"
      shift 2
      ;;
    --author)
      AUTHOR="${2:?--author requires a value}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if ! command -v gh >/dev/null 2>&1; then
  echo "Error: gh CLI is required" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required" >&2
  exit 1
fi

if [[ -z "$REPO" ]]; then
  if ! REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)"; then
    echo "Error: could not detect repo. Pass --repo OWNER/REPO." >&2
    exit 1
  fi
fi

date_offset() {
  local days="$1"
  if date -v-1d +%Y-%m-%d >/dev/null 2>&1; then
    date -v-"${days}"d +%Y-%m-%d
  else
    date -d "${days} days ago" +%Y-%m-%d
  fi
}

resolve_since() {
  local input="$1"
  local since_date since_label dow days_back

  case "$input" in
    friday)
      SINCE_ALIAS="friday"
      dow=$(date +%u)
      days_back=$(( (dow + 2) % 7 ))
      [[ "$days_back" -eq 0 ]] && days_back=7
      since_date=$(date_offset "$days_back")
      since_label="sexta-feira"
      ;;
    monday)
      SINCE_ALIAS="monday"
      dow=$(date +%u)
      days_back=$(( dow - 1 ))
      [[ "$days_back" -le 0 ]] && days_back=$(( days_back + 7 ))
      since_date=$(date_offset "$days_back")
      since_label="segunda-feira"
      ;;
    today)
      SINCE_ALIAS="today"
      since_date=$(date +%Y-%m-%d)
      since_label="hoje"
      ;;
    *-days)
      SINCE_ALIAS="$input"
      local n="${input%-days}"
      if ! [[ "$n" =~ ^[0-9]+$ ]]; then
        echo "Error: invalid --since value: $input" >&2
        exit 1
      fi
      since_date=$(date_offset "$n")
      since_label="${n} dias"
      ;;
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9])
      SINCE_ALIAS="date"
      since_date="$input"
      if date -j -f "%Y-%m-%d" "$since_date" +%d/%m >/dev/null 2>&1; then
        since_label=$(date -j -f "%Y-%m-%d" "$since_date" +%d/%m)
      else
        since_label=$(date -d "$since_date" +%d/%m)
      fi
      ;;
    *)
      echo "Error: invalid --since value: $input" >&2
      exit 1
      ;;
  esac

  SINCE_DATE="$since_date"
  SINCE_LABEL="$since_label"
  SINCE_ISO="${since_date}T00:00:00Z"
}

resolve_since "$SINCE_INPUT"

truncate() {
  local text="$1"
  local max="${2:-500}"
  if [[ ${#text} -gt $max ]]; then
    printf '%s' "${text:0:max}"
  else
    printf '%s' "$text"
  fi
}

extract_pending_steps() {
  local body="$1"
  printf '%s' "$body" | awk '
    /^## Steps|^### Step/ { in_steps=1; next }
    /^## / && !/^## Steps/ { if (in_steps) in_steps=0 }
    in_steps && /- \[ \]/ { print }
  ' | head -20
}

extract_blockers() {
  local text="$1"
  printf '%s' "$text" | grep -iE 'bloqueador|bloqueado|gate|blocked|depends on|⬜|prerequisite|pré-requisito' | head -10 || true
}

fetch_issue_comments() {
  local number="$1"
  gh api "repos/${REPO}/issues/${number}/comments" \
    --jq '[.[] | {created_at, body: (.body | .[0:800])}]' 2>/dev/null || echo '[]'
}

fetch_issue_timeline() {
  local number="$1"
  local filter="[.[] | select(.created_at >= \"${SINCE_ISO}\")"
  if [[ -n "$AUTHOR" ]]; then
    filter+=" | select((.actor.login // .user.login // \"\") == \"${AUTHOR}\")"
  fi
  filter+=' | {event, created_at, actor: (.actor.login // .user.login // null), body: (if .body then (.body | .[0:300]) else null end)}]'

  gh api "repos/${REPO}/issues/${number}/timeline" --jq "$filter" 2>/dev/null || echo '[]'
}

build_summary_hints() {
  local number="$1"
  local body="$2"
  local timeline="$3"
  local comments="$4"

  local hints=""
  hints+=$(printf '%s' "$body" | head -c 400)
  hints+=$'\n'

  local session_comments
  session_comments=$(printf '%s' "$comments" | jq -r --arg since "$SINCE_ISO" \
    '[.[]? | select(.created_at >= $since) | .body] | join("\n")' 2>/dev/null || echo "")
  if [[ -n "$session_comments" ]]; then
    hints+=$'\n'
    hints+=$(truncate "$session_comments" 600)
  fi

  local timeline_comments
  timeline_comments=$(printf '%s' "$timeline" | jq -r \
    '[.[] | select(.event == "commented" and .body != null) | .body] | join("\n")' 2>/dev/null || echo "")
  if [[ -n "$timeline_comments" ]]; then
    hints+=$'\n'
    hints+=$(truncate "$timeline_comments" 400)
  fi

  truncate "$hints" 1200
}

# Closed issues updated since date (filter closed_at in jq)
# Include PR-backed issues — they are often merge tracking items.
CLOSED_RAW=$(gh api "repos/${REPO}/issues?state=closed&sort=updated&direction=desc&per_page=100&since=${SINCE_ISO}" \
  --paginate \
  --jq '[.[] | {number, title, body, closed_at, updated_at, is_pull_request: (.pull_request != null)}]' 2>/dev/null || echo '[]')

COMPLETED_JSON='[]'
while IFS= read -r issue; do
  [[ -z "$issue" || "$issue" == "null" ]] && continue

  closed_at=$(printf '%s' "$issue" | jq -r '.closed_at // empty')
  [[ -z "$closed_at" || "$closed_at" < "$SINCE_ISO" ]] && continue

  number=$(printf '%s' "$issue" | jq -r '.number')
  title=$(printf '%s' "$issue" | jq -r '.title')
  body=$(printf '%s' "$issue" | jq -r '.body // ""')
  is_pr=$(printf '%s' "$issue" | jq -r '.is_pull_request')
  comments=$(fetch_issue_comments "$number")
  timeline=$(fetch_issue_timeline "$number")
  if ! printf '%s' "$comments" | jq empty 2>/dev/null; then comments='[]'; fi
  if ! printf '%s' "$timeline" | jq empty 2>/dev/null; then timeline='[]'; fi
  summary_hints=$(build_summary_hints "$number" "$body" "$timeline" "$comments")

  entry=$(jq -n \
    --argjson number "$number" \
    --arg title "$title" \
    --arg closed_at "$closed_at" \
    --arg body_excerpt "$(truncate "$body" 500)" \
    --arg summary_hints "$summary_hints" \
    --argjson timeline "$timeline" \
    --argjson comments "$comments" \
    --argjson is_pull_request "$is_pr" \
  '{
    number: $number,
    title: $title,
    closed_at: $closed_at,
    body_excerpt: $body_excerpt,
    summary_hints: $summary_hints,
    timeline_events: $timeline,
    has_merged_pr: ([$timeline[]? | select(.event == "merged")] | length > 0),
    is_pull_request: $is_pull_request
  }')

  COMPLETED_JSON=$(printf '%s' "$COMPLETED_JSON" | jq --argjson entry "$entry" '. + [$entry]')
done < <(printf '%s' "$CLOSED_RAW" | jq -c '.[]')

# Open issues
OPEN_RAW=$(gh api "repos/${REPO}/issues?state=open&sort=updated&direction=desc&per_page=100" \
  --paginate \
  --jq '[.[] | select(.pull_request == null)]' 2>/dev/null || echo '[]')

OPEN_JSON='[]'
while IFS= read -r issue; do
  [[ -z "$issue" || "$issue" == "null" ]] && continue

  number=$(printf '%s' "$issue" | jq -r '.number')
  title=$(printf '%s' "$issue" | jq -r '.title')
  body=$(printf '%s' "$issue" | jq -r '.body // ""')
  updated_at=$(printf '%s' "$issue" | jq -r '.updated_at')
  comments=$(fetch_issue_comments "$number")
  if ! printf '%s' "$comments" | jq empty 2>/dev/null; then comments='[]'; fi

  pending_steps=$(extract_pending_steps "$body")
  blockers_from_body=$(extract_blockers "$body")

  comments_text=$(printf '%s' "$comments" | jq -r '[.[].body] | join("\n")' 2>/dev/null || echo "")
  blockers_from_comments=$(extract_blockers "$comments_text")

  blockers_combined=""
  if [[ -n "$blockers_from_body" ]]; then
    blockers_combined+="$blockers_from_body"
  fi
  if [[ -n "$blockers_from_comments" ]]; then
    blockers_combined+=$'\n'"$blockers_from_comments"
  fi

  next_steps_json=$(printf '%s' "$pending_steps" | jq -R -s 'split("\n") | map(select(length > 0))' 2>/dev/null || echo '[]')

  blockers_json=$(printf '%s' "$blockers_combined" | jq -R -s 'split("\n") | map(select(length > 0)) | unique' 2>/dev/null || echo '[]')

  entry=$(jq -n \
    --argjson number "$number" \
    --arg title "$title" \
    --arg updated_at "$updated_at" \
    --arg body_excerpt "$(truncate "$body" 800)" \
    --argjson next_steps "$next_steps_json" \
    --argjson blockers "$blockers_json" \
    --argjson comments "$comments" \
  '{
    number: $number,
    title: $title,
    updated_at: $updated_at,
    body_excerpt: $body_excerpt,
    next_steps: $next_steps,
    blockers: $blockers,
    comment_count: ($comments | length)
  }')

  OPEN_JSON=$(printf '%s' "$OPEN_JSON" | jq --argjson entry "$entry" '. + [$entry]')
done < <(printf '%s' "$OPEN_RAW" | jq -c '.[]')

jq -n \
  --arg repo "$REPO" \
  --arg since "$SINCE_DATE" \
  --arg since_label "$SINCE_LABEL" \
  --arg since_iso "$SINCE_ISO" \
  --arg since_alias "$SINCE_ALIAS" \
  --argjson completed "$COMPLETED_JSON" \
  --argjson open "$OPEN_JSON" \
  '{
    repo: $repo,
    since: $since,
    since_label: $since_label,
    since_iso: $since_iso,
    since_alias: $since_alias,
    completed: ($completed | sort_by(.closed_at)),
    open: ($open | sort_by(.updated_at) | reverse)
  }'
