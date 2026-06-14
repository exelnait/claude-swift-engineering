# Claude Code Hooks

This directory contains hook scripts that enhance Claude Code's behavior.

## Quick Setup

### Step 1: Symlink hooks-scripts to your .claude directory

```bash
# From the swift-engineering plugin directory
ln -s $(pwd)/hooks-scripts ~/.claude/hooks-scripts
```

Or if you know the full path:

```bash
ln -s /path/to/claude-swift-engineering/plugins/swift-engineering/hooks-scripts ~/.claude/hooks-scripts
```

### Step 2: Add hooks to ~/.claude/settings.json

Edit your `~/.claude/settings.json` and add the UserPromptSubmit hook to the `hooks` section:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "cat ~/.claude/hooks-scripts/UserPromptSubmit/skill-forced-eval-hook.sh"
          }
        ]
      }
    ]
  }
}
```

If you already have other hooks defined, just add the `UserPromptSubmit` entry alongside them.

## Available Hooks

### UserPromptSubmit: skill-forced-eval-hook.sh

**Purpose:** Forces explicit skill evaluation before implementation.

**What it does:**
- Requires you to evaluate each available skill (YES/NO)
- Ensures you activate relevant skills via the Skill tool
- Prevents skipping directly to implementation

**Activation sequence (enforced by hook):**
1. **EVALUATE** — For each skill: `[skill-name] - YES/NO - [reason]`
2. **ACTIVATE** — Use `Skill(skill-name)` for each YES
3. **IMPLEMENT** — Only after activation is complete

### PostToolUse: evaluation-sync-hook.sh

**Purpose:** Reminds you to create or update a feature's Evaluation the moment you edit an AI/Foundation Models feature file.

**What it does:**
- Fires after `Edit` / `Write` / `MultiEdit`.
- Inspects the edited Swift file; if it uses Foundation Models (`import FoundationModels`, `LanguageModelSession`, `SystemLanguageModel`, `@Generable`) and is *not* itself a test/evaluation file, it injects a reminder to create/update the Evaluation, cover every supported language, and re-run it.
- This is a **nudge** (injected context), not a block. Fail-open: if `jq` is missing or the payload is unexpected, it does nothing.

### Stop: evaluation-gate-hook.sh

**Purpose:** Hard end-of-turn gate — the guarantee that complements the nudge. Prevents finishing a turn that changed an AI/FM feature without touching its Evaluation.

**What it does:**
- Runs when Claude tries to stop.
- Scans the git working tree (changed vs `HEAD` + untracked). If an AI/FM feature file changed but **no** Evaluation file changed (`import Evaluations`, a type conforming to `Evaluation`, `.evaluates(`, `ModelJudgeEvaluator`, `ScoreDimension`), it **blocks once** with instructions to update + re-run the evaluation, or to explain why no change is needed.
- **Loop-guarded:** honours `stop_hook_active`, so it blocks at most once per stop sequence and can never trap the session.
- **Conservative & fail-open:** only blocks when confident; if `git`/`jq` are absent or it isn't a repo, it does nothing.

> **Important:** Unlike the `UserPromptSubmit` hook (which is `cat`-ed so its text is injected verbatim), the `PostToolUse` and `Stop` hooks are **executed scripts** that read a JSON payload on stdin — wire them with `bash <script>`, not `cat <script>`.

### settings.json wiring for the evaluation hooks

Add alongside any existing hooks:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks-scripts/PostToolUse/evaluation-sync-hook.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks-scripts/Stop/evaluation-gate-hook.sh"
          }
        ]
      }
    ]
  }
}
```

Both hooks are **opt-in** and **language-agnostic to your project** — they only react to Swift files that use Foundation Models, so they stay silent on non-AI work.

## How Hooks Work

When a hook is configured:
1. Claude Code executes the hook command before processing user input
2. The command output is displayed as instructions
3. You must follow the instructions before proceeding

The hook ensures discipline around skill selection and prevents jumping to implementation without evaluating available tools.
