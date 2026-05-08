---
name: codex-dual
description: Use when the user asks Claude Code to use two independent Codex reasoning sessions, compare Codex 5.4 and 5.5 answers, run dual Codex review, consult both Codex lanes, or open/resume both GPT-5.4 xhigh and GPT-5.5 xhigh Codex sessions for the same task.
---

# Dual Codex Skill Guide

## Purpose
Use two independent Codex reasoning lanes for the same user task:

| Lane | Model | Reasoning effort | Session key |
| --- | --- | --- | --- |
| Codex 5.4 | `gpt-5.4` | `xhigh` | `codex-dual-5.4-xhigh` |
| Codex 5.5 | `gpt-5.5` | `xhigh` | `codex-dual-5.5-xhigh` |

Store and resume each lane separately inside the current Claude conversation. Keep these dual-lane sessions independent from the single-lane `codex-5.4-xhigh` and `codex-5.5-xhigh` sessions. Never substitute one lane for the other, and never use `resume --last`.

## Running Dual Reasoning
1. Build one clear prompt that asks each Codex lane for independent analysis. Tell each lane not to assume the other lane's answer and to focus on the requested task.
2. For each lane, either resume the stored session ID for that lane or start a new session if no ID exists.
3. Extract and store each session ID from its own stderr file after every run:
   - 5.4 stderr: `/tmp/codex54-stderr.txt`
   - 5.5 stderr: `/tmp/codex55-stderr.txt`
4. Read both stdout results, compare them yourself, and return a synthesized answer to the user. Do not simply concatenate both outputs.
5. If the two lanes disagree, identify the disagreement, evaluate it, and state which answer you trust more and why.

## Safety
- Use dual Codex primarily as **two reasoning advisors**. For code edits in the user's working tree, prefer having both lanes propose/review and then apply the final changes yourself.
- Do not run both lanes with broad write access against the same worktree at the same time. If the user explicitly wants two editing agents, use separate worktrees or run them sequentially with clear ownership.
- For pure review, architecture, planning, debugging, or second-opinion work, start new dual lanes with `--sandbox read-only` unless the user asks for edit capability.
- For implementation work where Codex should directly edit, ask which single lane should edit or use a separate worktree per lane.

## Starting New Lanes
Use lane-specific commands and stderr files.

### New 5.4 lane
```bash
codex exec -m gpt-5.4 \
  --config model_reasoning_effort="xhigh" \
  --sandbox read-only \
  --enable fast_mode \
  --skip-git-repo-check \
  "your prompt here" 2>/tmp/codex54-stderr.txt
```

Use `--sandbox danger-full-access --full-auto` instead of `--sandbox read-only` only when the user explicitly wants that lane to edit or needs broad access.

### New 5.5 lane
```bash
codex exec -m gpt-5.5 \
  --config model_reasoning_effort="xhigh" \
  --sandbox read-only \
  --enable fast_mode \
  --skip-git-repo-check \
  "your prompt here" 2>/tmp/codex55-stderr.txt
```

Use `--sandbox danger-full-access --full-auto` instead of `--sandbox read-only` only when the user explicitly wants that lane to edit or needs broad access.

### Long prompt workaround
For long or file-sourced prompts on new sessions, write the prompt to a file and redirect via stdin, omitting the positional argument:

```bash
codex exec -m gpt-5.5 --config model_reasoning_effort="xhigh" --sandbox read-only --enable fast_mode --skip-git-repo-check < /tmp/prompt.txt 2>/tmp/codex55-stderr.txt
```

Do not use stdin piping for resume.

## Resuming Lanes
Resume each lane by its stored ID and pass the new prompt as the positional argument:

```bash
codex exec --skip-git-repo-check resume <CODEX54_SESSION_ID> "your prompt here" 2>/tmp/codex54-stderr.txt
codex exec --skip-git-repo-check resume <CODEX55_SESSION_ID> "your prompt here" 2>/tmp/codex55-stderr.txt
```

Do not pass model, reasoning, sandbox, or fast-mode flags on resume unless the user explicitly requests it. The resumed session inherits the original lane settings.

## Extracting Session IDs
After each run, extract the session ID from the matching stderr file:

```bash
grep -a 'session id:' /tmp/codex54-stderr.txt | sed 's/\x1b\[[0-9;]*m//g' | awk -F'session id: ' '{print $2}' | tr -d '[:space:]'
grep -a 'session id:' /tmp/codex55-stderr.txt | sed 's/\x1b\[[0-9;]*m//g' | awk -F'session id: ' '{print $2}' | tr -d '[:space:]'
```

Store the 5.4 ID only under `codex-dual-5.4-xhigh` and the 5.5 ID only under `codex-dual-5.5-xhigh`.

## Reporting
- Restate that the result used two independent Codex lanes: `gpt-5.4/xhigh` and `gpt-5.5/xhigh`.
- Summarize the consensus first, then the important disagreements.
- Keep the final answer grounded in your own evaluation. Codex output is advisory.
- If either lane fails, report which lane failed and continue with the successful lane only if the user can still benefit from a partial result.
