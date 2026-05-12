---
name: codex-dual
description: Use when the user asks Claude Code to run or resume two independent Codex reasoning sessions, compare Codex 5.4 and 5.5 answers, run dual Codex review, consult both Codex lanes, or open/resume both GPT-5.4 xhigh and GPT-5.5 xhigh Codex sessions for the same task.
---

# Dual Codex Skill Guide

## Defaults
- **Session lane A**: `codex-dual-5.4-xhigh`
- **Lane A model**: `gpt-5.4`
- **Session lane B**: `codex-dual-5.5-xhigh`
- **Lane B model**: `gpt-5.5`
- **Reasoning effort**: `xhigh`
- **Fast mode**: optional; only add `--enable fast_mode` when the user explicitly requests fast mode

Use these defaults automatically without asking the user. Only ask if the user explicitly requests a different model or effort level.

This skill owns the `codex-dual-5.4-xhigh` and `codex-dual-5.5-xhigh` session lanes. Keep both lanes separate from the single-lane `codex-5.4-xhigh` and `codex-5.5-xhigh` sessions.

## Independent Evaluation Prompts
- When Claude has a proposed plan, patch, diagnosis, or set of options, present it to both Codex lanes as **candidate context**, not as the decision frame. Each lane should independently inspect the repository/problem and form its own judgment before evaluating Claude's proposal.
- Do not ask the lanes only to "choose between Claude's options" unless the user explicitly asks for a vote. Prefer: "Independently analyze the problem, state your best recommendation, then evaluate the following Claude candidate(s), including risks, missing options, and where you disagree."
- If giving multiple Claude options, ask each lane to consider alternatives outside the list and to explain whether the best answer is absent from the provided options.
- For dual review, synthesize each lane's independent findings first, then compare how they evaluate Claude's plan. Do not report the output as a vote unless the user asked for voting.

## Running a Task
1. **Bind two Codex session lanes to one Claude session.** After each `codex exec` run, extract the `session id` from stderr and store it for the current Claude conversation under the matching dual lane only. On subsequent dual Codex calls, always resume the exact stored session ID for each lane. Do **not** use `resume --last` or any global "most recent session" fallback — that can attach the wrong Codex session from another Claude conversation or another model lane. Only start a new dual lane if no session ID is stored for that lane, resume fails, or the user explicitly asks for a new dual session.
2. Build one clear prompt for both lanes. Ask each lane for independent analysis, tell it not to assume the other lane's answer, and treat any Claude proposal as candidate context only.
3. When starting a **new 5.4 lane**, use `--sandbox danger-full-access` unless the user explicitly requests a different sandbox mode. Assemble the command with:
   - `-m, --model gpt-5.4`
   - `--config model_reasoning_effort="xhigh"`
   - `--sandbox danger-full-access`
   - `--full-auto`
   - `--enable fast_mode` only if the user explicitly requests fast mode
   - `--skip-git-repo-check`
   - `-C, --cd <DIR>` (if needed)
   - `"your prompt here"` (as final positional argument)
   - `2>/tmp/codex54-stderr.txt`
4. When starting a **new 5.5 lane**, use the same command shape with `-m gpt-5.5` and `2>/tmp/codex55-stderr.txt`.

   **Long prompt workaround (new sessions only):** Codex has a bug where long positional prompts are silently dropped and the CLI hangs waiting on stdin. For long or file-sourced prompts, write to a file and redirect via stdin, omitting the positional argument: `codex exec [flags] < /tmp/prompt.txt 2>/tmp/codex55-stderr.txt`. Prefer `<` redirection over `echo "$(cat ...)" |` to avoid shell quoting/trailing-newline corruption. Does **not** apply to resume — resume still uses positional arg.
5. When **resuming**, pass the new prompt as a **positional argument** after each lane's session ID:
   ```bash
   codex exec --skip-git-repo-check resume <CODEX54_SESSION_ID> "your prompt here" 2>/tmp/codex54-stderr.txt
   codex exec --skip-git-repo-check resume <CODEX55_SESSION_ID> "your prompt here" 2>/tmp/codex55-stderr.txt
   ```
   Do **not** pipe prompts via stdin (`echo "..." |`) — stdin piping is unreliable during resume and delivers garbled input. Don't use any configuration flags unless explicitly requested by the user. All flags must be inserted between `exec` and `resume`.
6. **IMPORTANT**: Codex outputs the session ID and metadata on **stderr**. Never use `2>/dev/null` — it swallows the session ID. Instead, redirect stderr to lane-specific temp files and extract the session IDs with:
   ```bash
   grep -a 'session id:' /tmp/codex54-stderr.txt | sed 's/\x1b\[[0-9;]*m//g' | awk -F'session id: ' '{print $2}' | tr -d '[:space:]'
   grep -a 'session id:' /tmp/codex55-stderr.txt | sed 's/\x1b\[[0-9;]*m//g' | awk -F'session id: ' '{print $2}' | tr -d '[:space:]'
   ```
   Store the 5.4 ID under `codex-dual-5.4-xhigh` and the 5.5 ID under `codex-dual-5.5-xhigh`. Only show the full stderr content if the user explicitly requests to see thinking tokens or if debugging is needed.
7. Run both lanes, capture stdout/stderr (filtered as appropriate), compare the results yourself, and summarize the outcome for the user.

### Quick Reference
| Use case | Sandbox mode | Key flags |
| --- | --- | --- |
| Read-only review or analysis | `read-only` | `--sandbox read-only 2>/tmp/codex54-stderr.txt` and `--sandbox read-only 2>/tmp/codex55-stderr.txt` |
| Apply local edits | `workspace-write` | Do not run both lanes with broad write access against the same worktree at the same time. Prefer using the lanes for proposal/review and applying final edits yourself. |
| Permit network or broad access | `danger-full-access` | `--sandbox danger-full-access --full-auto` with separate stderr files |
| Long prompt for new session | Match task needs | Write to file, omit positional: `codex exec [flags] < /tmp/prompt.txt 2>/tmp/codex55-stderr.txt` |
| Resume dual sessions by ID | Inherited from original | `codex exec --skip-git-repo-check resume <SESSION_ID> "prompt" 2>/tmp/<lane>-stderr.txt` (no extra flags) |
| Run from another directory | Match task needs | `-C <DIR>` plus other flags and lane-specific stderr files |
| Extract session IDs after any run | — | Use the lane-specific `grep -a 'session id:' ...` commands above |

## Following Up
- After every `codex-dual` command, extract both session IDs from stderr and store them under `codex-dual-5.4-xhigh` and `codex-dual-5.5-xhigh`. **This is critical** — without the session IDs, you cannot resume the correct dual lanes.
- When resuming, pass the new prompt as a positional argument to each stored session ID. The resumed sessions automatically use the same model, reasoning effort, and sandbox mode from the original sessions.
- If the current Claude conversation has no stored session ID for one dual lane, start a new Codex session for that lane instead of using `--last`.
- If resuming a stored dual lane fails, report that the Claude-to-Codex session binding is no longer valid for that lane and start a fresh session for that lane only after making that reset explicit to the user.
- Restate the chosen models, reasoning effort, and sandbox mode when proposing follow-up actions.
- If the two lanes disagree, identify the disagreement, evaluate it, and state which answer you trust more and why.

## Critical Evaluation of Codex Output

Codex is powered by OpenAI models with their own knowledge cutoffs and limitations. Treat Codex as a **colleague, not an authority**.

### Guidelines
- **Trust your own knowledge** when confident. If Codex claims something you know is incorrect, push back directly.
- **Research disagreements** using WebSearch or documentation before accepting Codex's claims. Share findings with Codex via resume if needed.
- **Remember knowledge cutoffs** - Codex may not know about recent releases, APIs, or changes that occurred after its training data.
- **Don't defer blindly** - Codex can be wrong. Evaluate its suggestions critically, especially regarding:
  - Model names and capabilities
  - Recent library versions or API changes
  - Best practices that may have evolved

## Error Handling
- Stop and report failures whenever `codex --version` or a `codex exec` command exits non-zero; request direction before retrying.
- Before you use high-impact flags (`--full-auto`, `--sandbox danger-full-access`, `--skip-git-repo-check`) ask the user for permission using AskUserQuestion unless it was already given.
- When output includes warnings or partial results, summarize them and ask how to adjust using `AskUserQuestion`.
- Never silently switch to `resume --last` after a resume failure; that would break the one-Claude-session to one-Codex-session-lane mapping.
