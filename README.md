Note: If you want a more autonomous setup for agentic workflows, check out [klaudworks/ralph-meets-rex](https://github.com/klaudworks/ralph-meets-rex).

# Codex Integration for Claude Code

<img width="2288" height="808" alt="skillcodex" src="https://github.com/user-attachments/assets/85336a9f-4680-479e-b3fe-d6a68cadc051" />


## Purpose
Enable Claude Code to invoke the Codex CLI (`codex exec` and session resumes) for automated code analysis, refactoring, and editing workflows.

## Prerequisites
- `codex` CLI installed and available on `PATH`.
- Codex configured with valid credentials and settings.
- Confirm the installation by running `codex --version`; resolve any errors before using the skill.

## Installation

This repository is structured as a [Claude Code Plugin](https://code.claude.com/docs/en/plugins) with a marketplace. You can install it as a **plugin** (recommended) or extract it as a **standalone skill**.

### Option 1: Plugin Installation (Recommended)

Install via Claude Code's plugin system for automatic updates:

```
/plugin marketplace add aysuio/skill-codex
/plugin install skill-codex@skill-codex
```

### Option 2: Standalone Skill Installation

Extract the skill folder manually:

```
git clone --depth 1 git@github.com:aysuio/skill-codex.git /tmp/skills-temp && \
mkdir -p ~/.claude/skills && \
cp -r /tmp/skills-temp/plugins/skill-codex/skills/codex ~/.claude/skills/codex && \
rm -rf /tmp/skills-temp
```

## Usage

### Important: Thinking Tokens
By default, this skill captures stderr in a temporary file so it can extract the Codex `session id`, but it does not include that stderr in Claude Code's response. Do not use `2>/dev/null`, because that discards the session ID and prevents reliable session reuse. If you want to see the thinking tokens for debugging or insight into Codex's reasoning process, explicitly ask Claude to show them.

### Session Affinity
Each Claude Code conversation should own one Codex session per model lane. The skill should capture the `session id` created for that lane and resume that exact session on follow-up turns. It should not fall back to `resume --last`, because "most recent" can point at a different Claude conversation, repository, or model lane.

Available session commands:
- `/skill-codex:codex` (or `/codex` when installed standalone): `gpt-5.4`, `xhigh`, session key `codex-5.4-xhigh`
- `/skill-codex:codex55` (or `/codex55` when installed standalone): `gpt-5.5`, `xhigh`, session key `codex-5.5-xhigh`
- `/skill-codex:codex-dual` (or `/codex-dual` when installed standalone): run or resume two separate dual-reasoning lanes, `codex-dual-5.4-xhigh` and `codex-dual-5.5-xhigh`

### Example Workflow

**User prompt:**
```
Use codex to analyze this repository and suggest improvements for my claude code skill.
```

**Claude Code response:**
Claude will activate the Codex skill and:
1. Use default model (`gpt-5.4`), reasoning effort (`xhigh`), and sandbox (`danger-full-access`) automatically
2. Run a command like:
```bash
codex exec -m gpt-5.4 \
  --config model_reasoning_effort="xhigh" \
  --sandbox danger-full-access \
  --full-auto \
  --skip-git-repo-check \
  "Analyze this Claude Code skill repository comprehensively..." 2>/tmp/codex-stderr.txt
```

**Result:**
Claude will summarize the Codex analysis output, highlighting key suggestions and asking if you'd like to continue with follow-up actions.

### Dual Reasoning Workflow

Use both independent Codex sessions when you want Claude Code to compare two reasoning passes:

```
/skill-codex:codex-dual review this refactor plan and point out risks
```

Claude Code will run or resume the `gpt-5.4/xhigh` and `gpt-5.5/xhigh` dual lanes separately, keep their session IDs isolated from the single-lane commands, then synthesize the consensus and disagreements.

### Detailed Instructions
See [`plugins/skill-codex/skills/codex/SKILL.md`](plugins/skill-codex/skills/codex/SKILL.md), [`plugins/skill-codex/skills/codex55/SKILL.md`](plugins/skill-codex/skills/codex55/SKILL.md), and [`plugins/skill-codex/skills/codex-dual/SKILL.md`](plugins/skill-codex/skills/codex-dual/SKILL.md) for complete operational instructions, CLI options, and workflow guidance.
