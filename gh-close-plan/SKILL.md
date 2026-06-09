---
name: gh-close-plan
description: Close a GitHub plan issue with a summary. Use when the user tells you to "close the github plan issue".
argument-hint: "[owner/repo#number]"
allowed-tools: Bash, Read, Write, Edit
---

Never @mention other users in plan issues or comments.

Close the GitHub issue $ARGUMENTS (issue URL or `owner/repo#number`). If no argument is given, use the issue referenced earlier in this conversation. If no issue can be determined, ask the user.

**Comment preservation:** Do not delete issue comments when closing a plan. Only add new comments (Commits table, Session Log, closing summary). Never call `gh api -X DELETE` on issue comments.

**Workflow for editing issue bodies and comments:**
1. Create a unique temp directory: `mktemp -d /tmp/plan-close-XXXXX`
2. Fetch content from GitHub using `gh api` and capture the output. Use the Write tool to save it to files in the temp directory (e.g. `body.md`, `comment-COMMENTID.md`). Do NOT use shell redirects (`>`) to write files, as this triggers permission prompts.
3. Use the Read and Edit tools to modify the temp files (not shell commands like sed/awk).
4. Upload using `--input` with `jq` to properly JSON-encode the content:

- Edit issue body: `jq -Rs '{body: .}' <tempdir>/body.md | gh api repos/OWNER/REPO/issues/NUMBER -X PATCH --input -`
- Create comment: `jq -Rs '{body: .}' <tempdir>/comment.md | gh api repos/OWNER/REPO/issues/NUMBER/comments --input -`
- Edit comment: `jq -Rs '{body: .}' <tempdir>/comment-COMMENTID.md | gh api repos/OWNER/REPO/issues/comments/COMMENT_ID -X PATCH --input -` (only for updating the **Commits** table comment in step 4 — never to remove session comments)

Never embed content directly in shell arguments or use `-f body=@file` (it uploads the literal string, not the file contents). Always fetch the latest from GitHub before making changes. Do not rely on previously fetched copies that may be stale.

1. Read the issue and its comments to understand the full history of the work.
2. Check off completed steps (`- [x]`) based on the work done. Steps may be in a separate **Steps** comment (new format) or in the issue body (old format). Check both locations.
3. Verify that all steps are checked off. If any are incomplete, ask the user whether to proceed or leave the issue open.
4. Add or update a **Commits** table comment with the final commit hashes from main. Feature branch hashes change after squash/rebase merge, so look up the corresponding commits on main and replace the old hashes.
5. **Add Session Log** (append only — do not delete or edit existing comments):
   - **Never delete** individual session comments (diagrams, Q&A, notes, etc.). Leave all existing issue comments intact.
   - At the end of the close workflow, **add** a new consolidated **Session Log** comment (always create a new comment; do not PATCH an existing Session Log).
   - Structure with dated sections (`### YYYY-MM-DD`) for each session that contributed something worth keeping.
   - Include only key findings, decisions, and insights. Drop sessions that had nothing noteworthy.
   - The Session Log is a summary index — it does not replace detailed comments elsewhere on the issue.
6. **Capture learnings**: Before closing, review the session for non-obvious discoveries worth persisting. Ask the user: "Anything worth capturing?" If yes, propose where each belongs:
   - **Instructions file** (CLAUDE.md, AGENTS.md, or similar): conventions, gotchas, build quirks
   - **Repo docs** (`docs/` or similar): architecture insights, design rationale useful to humans too
   - **Memory**: cross-project patterns, user preferences

   Apply confirmed items. If the user says nothing to capture, move on.
7. Add a closing comment summarizing:
   * What was accomplished
   * Links to the final PR(s) or commits
   * Any follow-up work or known limitations
8. Close the issue.
