---
name: gh-implement-plan-guided
description: Implement a GitHub plan issue step by step with layman explanations and explicit approval between steps. Use when the user asks to "implement the plan with explanations", "guided plan implementation", or wants plain-language updates before each step.
argument-hint: "[owner/repo#number]"
allowed-tools: Bash, Read, Grep, Glob, Edit, Write
---

Implement the plan from GitHub issue $ARGUMENTS (issue URL or `owner/repo#number`). If no argument is given, use the issue referenced earlier in this conversation. If no issue can be determined, ask the user.

1. **Prepare branch**: If on main/master, fetch the latest and create a feature branch with a descriptive name derived from the plan issue title. If already on a feature branch, continue on it.
2. **Read the issue** and identify all steps (checkboxes). Steps may be in a separate **Steps** comment (new format) or in the issue body (old format). Check both. Before starting implementation, think about the design: What abstractions are needed? Where should the boundaries be? Is there a simpler approach than what's described? Flag any design concerns to the user before coding.
3. **Present an overview** of all steps with status (done/pending). Do not go into technical detail yet.
4. **Before the first pending step**, explain that step in plain language (see template below) and **wait for explicit approval** (e.g. "pode continuar", "sim", "ok").
5. **For each pending step**, in order:
   a. Implement the change.
   b. Stage and commit the changes with a descriptive commit message. Do not reference the issue.
   c. Check off the step (`- [x]`) on the issue. Update wherever the steps are found (Steps comment or body).
   d. **Verify success** (see criteria below). If verification fails, stop and explain what went wrong — do not advance.
   e. **Plain-language summary** of what was just done (2–4 sentences).
   f. If there is a next step: **explain the next step** in plain language and **wait for approval** before returning to item (a).
6. **After all steps are complete**, present a summary of what was done for each step (files changed, key decisions). Tell the user to review the commits and push when ready.

## Plain-language explanation template

Use before each step and when previewing the next step. Write in the **same language as the conversation**. Avoid jargon; when technical terms are unavoidable, translate them in parentheses.

```markdown
### Próximo passo: [step title]

**O que vamos fazer:** [everyday-language action]
**Por que importa:** [practical benefit / problem it solves]
**O que vai mudar:** [areas of the system in simple terms, e.g. "reconciliation screen", "payments API"]
**O que você deve notar depois:** [visible or testable outcome]

Posso seguir com este passo?
```

## Success verification criteria

After each step, check **all** before considering it complete:

1. A new local commit exists with the step's changes (`git log -1`, `git diff` clean or only unrelated changes remain).
2. The corresponding checkbox is marked on the GitHub issue.
3. Quick sanity check when applicable: linter/tests mentioned in the step or an obvious project command.
4. No blocking errors reported during implementation.

If any criterion fails → stop, explain in plain language what is missing, and **do not** explain the next step yet.

## Rules

- Never commit directly to main/master — always work on a feature branch.
- Never push to remote — only stage and commit locally.
- If a step is unclear or seems wrong, stop and ask the user for clarification instead of guessing.
- If a step fails or produces unexpected results, stop and explain what happened before continuing.
- **Never** implement the next step in the same response that explains it — explanation and implementation are separate turns.
- If the user asks to skip a step or change order, stop and confirm before deviating from the plan.
- If the user says "continue until step X" or "do everything", explain that this skill requires step-by-step approval; suggest `/gh-implement-plan` for continuous execution.
