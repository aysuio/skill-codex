---
name: codex
description: Use when the user asks to run Codex CLI (codex exec, codex resume) or references OpenAI Codex for code analysis, refactoring, or automated editing
---

# Codex Skill Guide

## Defaults
- **Model**: `gpt-5.4`
- **Reasoning effort**: `xhigh`
- **Fast mode**: enabled (via `service_tier = "fast"` in codex config)

Use these defaults automatically without asking the user. Only ask if the user explicitly requests a different model or effort level.

## Running a Task
1. **Bind one Codex session to one Claude session.** After each `codex exec` run, extract the `session id` from stderr and store it for the current Claude conversation only. On subsequent Codex calls, always resume the exact stored session ID. Do **not** use `resume --last` or any global "most recent session" fallback — that can attach the wrong Codex session from another Claude conversation. Only start a new session if no session ID is stored, resume fails, or the user explicitly asks for a new session.
2. When starting a **new session**, use `--sandbox danger-full-access` unless the user explicitly requests a different sandbox mode. Assemble the command with:
   - `-m, --model <MODEL>`
   - `--config model_reasoning_effort="<xhigh|high|medium|low>"`
   - `--sandbox danger-full-access`
   - `--full-auto`
   - `--enable fast_mode`
   - `--skip-git-repo-check`
   - `-C, --cd <DIR>` (if needed)
   - `"your prompt here"` (as final positional argument)
3. When **resuming**, pass the new prompt as a **positional argument** after the session ID: `codex exec --skip-git-repo-check resume <SESSION_ID> "your prompt here" 2>/tmp/codex-stderr.txt`. Do **not** pipe prompts via stdin (`echo "..." |`) — stdin piping is unreliable during resume and delivers garbled input. Don't use any configuration flags unless explicitly requested by the user. All flags must be inserted between `exec` and `resume`.
4. **IMPORTANT**: Codex outputs the session ID and metadata on **stderr**. Never use `2>/dev/null` — it swallows the session ID. Instead, redirect stderr to a temp file (`2>/tmp/codex-stderr.txt`) and extract the session ID with: `grep -a 'session id:' /tmp/codex-stderr.txt | sed 's/\x1b\[[0-9;]*m//g' | awk -F'session id: ' '{print $2}' | tr -d '[:space:]'`. The `-a` flag and `sed` are required because Codex stderr contains ANSI escape codes that cause `grep` to treat the file as binary. After extracting the session ID, store it for subsequent resume calls. Only show the full stderr content if the user explicitly requests to see thinking tokens or if debugging is needed.
5. Run the command, capture stdout/stderr (filtered as appropriate), and summarize the outcome for the user.

### Quick Reference
| Use case | Sandbox mode | Key flags |
| --- | --- | --- |
| Read-only review or analysis | `read-only` | `--sandbox read-only 2>/tmp/codex-stderr.txt` |
| Apply local edits | `workspace-write` | `--sandbox workspace-write --full-auto 2>/tmp/codex-stderr.txt` |
| Permit network or broad access | `danger-full-access` | `--sandbox danger-full-access --full-auto 2>/tmp/codex-stderr.txt` |
| Resume session by ID | Inherited from original | `codex exec --skip-git-repo-check resume <SESSION_ID> "prompt" 2>/tmp/codex-stderr.txt` (no extra flags) |
| Run from another directory | Match task needs | `-C <DIR>` plus other flags `2>/tmp/codex-stderr.txt` |
| Extract session ID after any run | — | `grep -a 'session id:' /tmp/codex-stderr.txt \| sed 's/\\x1b\\[[0-9;]*m//g' \| awk -F'session id: ' '{print $2}' \| tr -d '[:space:]'` |

## Following Up
- After every `codex` command, extract the session ID from stderr: `grep -a 'session id:' /tmp/codex-stderr.txt | sed 's/\x1b\[[0-9;]*m//g' | awk -F'session id: ' '{print $2}' | tr -d '[:space:]'`. Store this ID for subsequent resume calls. **This is critical** — without the session ID, you cannot resume the correct session.
- When resuming, pass the new prompt as a positional argument: `codex exec --skip-git-repo-check resume <SESSION_ID> "new prompt" 2>/tmp/codex-stderr.txt`. The resumed session automatically uses the same model, reasoning effort, and sandbox mode from the original session.
- If the current Claude conversation has no stored Codex session ID, start a new Codex session instead of using `--last`.
- If resuming the stored session fails, report that the Claude-to-Codex session binding is no longer valid and start a fresh Codex session only after making that reset explicit to the user.
- Restate the chosen model, reasoning effort, and sandbox mode when proposing follow-up actions.

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

### When Codex is Wrong
1. State your disagreement clearly to the user
2. Provide evidence (your own knowledge, web search, docs)
3. Optionally resume the Codex session to discuss the disagreement. **Identify yourself as Claude** so Codex knows it's a peer AI discussion. Use your actual model name (e.g., the model you are currently running as) instead of a hardcoded name:
   ```bash
   codex exec --skip-git-repo-check resume <SESSION_ID> "This is Claude (<your current model name>) following up. I disagree with [X] because [evidence]. What's your take on this?" 2>/tmp/codex-stderr.txt
   ```
4. Frame disagreements as discussions, not corrections - either AI could be wrong
5. Let the user decide how to proceed if there's genuine ambiguity

## Error Handling
- Stop and report failures whenever `codex --version` or a `codex exec` command exits non-zero; request direction before retrying.
- Before you use high-impact flags (`--full-auto`, `--sandbox danger-full-access`, `--skip-git-repo-check`) ask the user for permission using AskUserQuestion unless it was already given.
- When output includes warnings or partial results, summarize them and ask how to adjust using `AskUserQuestion`.
- Never silently switch to `resume --last` after a resume failure; that would break the one-Claude-session to one-Codex-session mapping.
