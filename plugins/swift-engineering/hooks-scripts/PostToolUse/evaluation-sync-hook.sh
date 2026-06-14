#!/bin/bash
# PostToolUse hook: evaluation-sync-hook.sh
#
# Fires after Edit/Write/MultiEdit. When the edited file is an AI/Foundation
# Models feature file, it injects a reminder that the feature's Evaluation must
# be created or kept in sync (and must cover every supported language).
#
# Design notes:
#   - FAIL-OPEN: any missing dependency or unexpected input exits 0 silently so
#     the user's workflow is never blocked by this hook.
#   - This is a NUDGE (additionalContext), not a hard block. The hard gate lives
#     in the Stop hook (Stop/evaluation-gate-hook.sh).

set -u

# Read the hook payload from stdin.
INPUT="$(cat 2>/dev/null)" || exit 0

# Requires jq to parse the payload; if absent, do nothing.
command -v jq >/dev/null 2>&1 || exit 0

TOOL="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)"
case "$TOOL" in
  Edit|Write|MultiEdit) ;;
  *) exit 0 ;;
esac

FILE="$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
[ -n "$FILE" ] || exit 0

# Only Swift source files.
case "$FILE" in
  *.swift) ;;
  *) exit 0 ;;
esac

# Editing the evaluation/tests themselves is exactly what we want — don't nag.
case "$FILE" in
  *Tests/*|*Test.swift|*Tests.swift|*Eval*|*Evaluation*) exit 0 ;;
esac

# The file must exist so we can inspect its contents.
[ -f "$FILE" ] || exit 0

# Detect Foundation Models / language-model usage.
if ! grep -Eq 'import[[:space:]]+FoundationModels|LanguageModelSession|SystemLanguageModel|@Generable' "$FILE" 2>/dev/null; then
  exit 0
fi

NAME="${FILE##*/}"

MSG="AI/Foundation Models feature edited: ${NAME}. Per the evaluations coverage policy, this feature's Evaluation must be kept in sync. Before finishing this task: (1) create an Evaluation if none exists, or UPDATE the existing one (subject, dataset, metrics, model judges, expected values); (2) ensure EVERY supported language is represented and asserted per-language; (3) re-run the evaluation @Test against its optimization target. Use the 'evaluations' skill or delegate to @evaluation-engineer."

jq -n --arg ctx "$MSG" '{
  hookSpecificOutput: {
    hookEventName: "PostToolUse",
    additionalContext: $ctx
  }
}' 2>/dev/null

exit 0
