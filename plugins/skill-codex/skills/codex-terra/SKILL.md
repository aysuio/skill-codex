---
name: codex-terra
description: Use when the user asks to run Codex CLI with GPT-5.6 Terra extra-high reasoning, says Codex Terra or GPT-5.6 Terra, wants a second independent Codex reasoning lane, or wants a Codex session that is separate from the default GPT-5.6 Sol xhigh codex lane.
---

# Codex Terra Skill Guide

## Defaults
- **Session lane**: `codex-5.6-terra-xhigh`
- **Model**: `gpt-5.6-terra`
- **Reasoning effort**: `xhigh`
- **Fast mode**: optional; only add `--enable fast_mode` when the user explicitly requests fast mode

Use these defaults automatically without asking the user. Only ask if the user explicitly requests a different model or effort level.

This skill owns the `codex-5.6-terra-xhigh` session lane. Keep it independent from the default `codex-5.6-sol-xhigh` lane used by the `codex` skill. If the user asks for both independent Codex reasoners, use `codex-dual`; that skill owns separate dual-lane sessions.

## Independent Evaluation Prompts
- When Claude has a proposed plan, patch, diagnosis, or set of options, present it to Codex as **candidate context**, not as the decision frame. Codex should independently inspect the repository/problem and form its own judgment before evaluating Claude's proposal.
- Do not ask Codex only to "choose between Claude's options" unless the user explicitly asks for a vote. Prefer: "Independently analyze the problem, state your best recommendation, then evaluate the following Claude candidate(s), including risks, missing options, and where you disagree."
- If giving multiple Claude options, ask Codex to consider alternatives outside the list and to explain whether the best answer is absent from the provided options.
- For reviews, ask Codex to lead with concrete findings, evidence, and residual risks, then comment on Claude's plan as one input among others.

## Running a Task
1. **Bind one Codex session lane to one Claude session.** After each `codex exec` run, extract the `session id` from stderr and store it for the current Claude conversation under the `codex-5.6-terra-xhigh` lane only. On subsequent Terra Codex calls, always resume that exact stored session ID. Do **not** use `resume --last` or any global "most recent session" fallback — that can attach the wrong Codex session from another Claude conversation or another model lane. Only start a new Terra session if no `codex-5.6-terra-xhigh` session ID is stored, resume fails, or the user explicitly asks for a new Terra session.
2. When starting a **new session**, use `--sandbox danger-full-access` unless the user explicitly requests a different sandbox mode. Assemble the command with:
   - `-m, --model gpt-5.6-terra`
   - `--config model_reasoning_effort="xhigh"`
   - `--sandbox danger-full-access`
   - `--full-auto`
   - `--enable fast_mode` only if the user explicitly requests fast mode
   - `--skip-git-repo-check`
   - `-C, --cd <DIR>` (if needed)
   - `"your prompt here"` (as final positional argument)

   **Long prompt workaround (new sessions only):** Codex has a bug where long positional prompts are silently dropped and the CLI hangs waiting on stdin. For long or file-sourced prompts, write to a file and redirect via stdin, omitting the positional argument: `codex exec [flags] < /tmp/prompt.txt 2>/tmp/codex-terra-stderr.txt`. Prefer `<` redirection over `echo "$(cat ...)" |` to avoid shell quoting/trailing-newline corruption. Does **not** apply to resume — resume still uses positional arg (stdin piping garbles input during resume per step 3).
3. When **resuming**, pass the new prompt as a **positional argument** after the session ID: `codex exec --skip-git-repo-check resume <SESSION_ID> "your prompt here" 2>/tmp/codex-terra-stderr.txt`. Do **not** pipe prompts via stdin (`echo "..." |`) — stdin piping is unreliable during resume and delivers garbled input. Don't use any configuration flags unless explicitly requested by the user. All flags must be inserted between `exec` and `resume`.
4. **IMPORTANT**: Codex outputs the session ID and metadata on **stderr**. Never use `2>/dev/null` — it swallows the session ID. Instead, redirect stderr to a temp file (`2>/tmp/codex-terra-stderr.txt`) and extract the session ID with: `grep -a 'session id:' /tmp/codex-terra-stderr.txt | sed 's/\x1b\[[0-9;]*m//g' | awk -F'session id: ' '{print $2}' | tr -d '[:space:]'`. The `-a` flag and `sed` are required because Codex stderr contains ANSI escape codes that cause `grep` to treat the file as binary. After extracting the session ID, store it under `codex-5.6-terra-xhigh` for subsequent resume calls. Only show the full stderr content if the user explicitly requests to see thinking tokens or if debugging is needed.
5. Run the command, capture stdout/stderr (filtered as appropriate), and summarize the outcome for the user.

### Quick Reference
| Use case | Sandbox mode | Key flags |
| --- | --- | --- |
| Read-only review or analysis | `read-only` | `--sandbox read-only 2>/tmp/codex-terra-stderr.txt` |
| Apply local edits | `workspace-write` | `--sandbox workspace-write --full-auto 2>/tmp/codex-terra-stderr.txt` |
| Permit network or broad access | `danger-full-access` | `--sandbox danger-full-access --full-auto 2>/tmp/codex-terra-stderr.txt` |
| Long prompt for new session | Match task needs | Write to file, omit positional: `codex exec [flags] < /tmp/prompt.txt 2>/tmp/codex-terra-stderr.txt` |
| Resume Terra session by ID | Inherited from original | `codex exec --skip-git-repo-check resume <SESSION_ID> "prompt" 2>/tmp/codex-terra-stderr.txt` |
| Run from another directory | Match task needs | `-C <DIR>` plus other flags `2>/tmp/codex-terra-stderr.txt` |
| Extract Terra session ID after any run | — | `grep -a 'session id:' /tmp/codex-terra-stderr.txt \| sed 's/\\x1b\\[[0-9;]*m//g' \| awk -F'session id: ' '{print $2}' \| tr -d '[:space:]'` |

## Following Up
- After every `codex-terra` command, extract the session ID from `/tmp/codex-terra-stderr.txt` and store it under the `codex-5.6-terra-xhigh` lane. Do not overwrite or read the `codex-5.6-sol-xhigh` lane.
- When resuming, pass the new prompt as a positional argument: `codex exec --skip-git-repo-check resume <SESSION_ID> "new prompt" 2>/tmp/codex-terra-stderr.txt`. The resumed session automatically uses the same model, reasoning effort, and sandbox mode from the original session.
- If the current Claude conversation has no stored Terra Codex session ID, start a new Terra Codex session instead of using `--last`.
- If resuming the stored Terra session fails, report that the Claude-to-Codex Terra session binding is no longer valid and start a fresh Terra session only after making that reset explicit to the user.
- Restate the chosen model (`gpt-5.6-terra`), reasoning effort (`xhigh`), and sandbox mode when proposing follow-up actions.

## Critical Evaluation of Codex Output

Codex is powered by OpenAI models with their own knowledge cutoffs and limitations. Treat Codex as a **colleague, not an authority**.

### Guidelines
- **Trust your own knowledge** when confident. If Codex claims something you know is incorrect, push back directly.
- **Research disagreements** using WebSearch or documentation before accepting Codex's claims. Share findings with Codex via resume if needed.
- **Remember knowledge cutoffs** - Codex may not know about recent releases, APIs, or changes that occurred after its training data.
- **Don't defer blindly** - Codex can be wrong. Evaluate its suggestions critically, especially regarding model names, recent APIs, and best practices.

### When Codex is Wrong
1. State your disagreement clearly to the user.
2. Provide evidence (your own knowledge, web search, docs).
3. Optionally resume the Terra Codex session to discuss the disagreement. Identify yourself as Claude and use your actual model name:
   ```bash
   codex exec --skip-git-repo-check resume <SESSION_ID> "This is Claude (<your current model name>) following up. I disagree with [X] because [evidence]. What's your take on this?" 2>/tmp/codex-terra-stderr.txt
   ```
4. Frame disagreements as discussions, not corrections.
5. Let the user decide how to proceed if there's genuine ambiguity.

## Error Handling
- Stop and report failures whenever `codex --version` or a `codex exec` command exits non-zero; request direction before retrying.
- Before you use high-impact flags (`--full-auto`, `--sandbox danger-full-access`, `--skip-git-repo-check`) ask the user for permission using AskUserQuestion unless it was already given.
- When output includes warnings or partial results, summarize them and ask how to adjust using `AskUserQuestion`.
- Never silently switch to `resume --last` after a resume failure; that would break the one-Claude-session to one-Codex-session-lane mapping.
