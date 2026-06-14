#!/bin/bash
# Stop hook: evaluation-gate-hook.sh
#
# End-of-turn gate. If AI/Foundation Models feature files changed in the working
# tree but no Evaluation file was created or updated, block the stop ONCE and
# ask Claude to update + re-run the evaluation (or to explain why it isn't
# needed). This is the hard guarantee that complements the PostToolUse nudge.
#
# Design notes:
#   - FAIL-OPEN: missing git/jq, not a repo, or any error exits 0 (no block).
#   - LOOP-GUARDED: honours `stop_hook_active`, so it blocks at most once per
#     stop sequence and can never trap the session in an infinite loop.
#   - CONSERVATIVE: only blocks when an FM feature changed AND no evaluation
#     change is detected — minimising false positives.

set -u

INPUT="$(cat 2>/dev/null)" || exit 0
command -v jq  >/dev/null 2>&1 || exit 0
command -v git >/dev/null 2>&1 || exit 0

# Loop guard: if this stop was already triggered by a previous block, allow it.
ACTIVE="$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)"
[ "$ACTIVE" = "true" ] && exit 0

# Must be inside a git work tree.
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
cd "$ROOT" 2>/dev/null || exit 0

# Changed (vs HEAD) + untracked files.
CHANGED="$( { git diff --name-only HEAD 2>/dev/null; \
              git ls-files --others --exclude-standard 2>/dev/null; } | sort -u )"
[ -n "$CHANGED" ] || exit 0

fm_files=""
eval_changed=0

while IFS= read -r f; do
  [ -n "$f" ] || continue
  case "$f" in *.swift) ;; *) continue ;; esac
  [ -f "$f" ] || continue

  # An evaluation file changed → coverage is being maintained.
  if grep -Eq 'import[[:space:]]+Evaluations|:[[:space:]]*Evaluation[[:space:]{]|\.evaluates\(|ModelJudgeEvaluator|ScoreDimension' "$f" 2>/dev/null; then
    eval_changed=1
    continue
  fi

  # Skip test files when looking for feature changes.
  case "$f" in *Tests/*|*Test.swift|*Tests.swift) continue ;; esac

  # An FM feature file changed.
  if grep -Eq 'import[[:space:]]+FoundationModels|LanguageModelSession|SystemLanguageModel|@Generable' "$f" 2>/dev/null; then
    fm_files="${fm_files}  - ${f}\n"
  fi
done <<EOF
$CHANGED
EOF

# Gate only when an FM feature changed and no evaluation changed.
if [ -n "$fm_files" ] && [ "$eval_changed" -eq 0 ]; then
  REASON="$(printf 'Evaluation gate: these AI/Foundation Models feature files changed but no Evaluation was created or updated:\n%bEvery AI/FM feature must ship with an Evaluation that is kept in sync and covers EVERY supported language. Before finishing, EITHER:\n  1) create/update the Evaluation (subject, dataset, metrics, model judges, expected values), ensure per-language coverage, and re-run its @Test against the optimization target — use the '\''evaluations'\'' skill or @evaluation-engineer; OR\n  2) if no evaluation change is genuinely needed (e.g. a comment or pure rename), state why explicitly.\n(This gate blocks only once; it will not run again on the next stop.)' "$fm_files")"
  jq -n --arg r "$REASON" '{decision: "block", reason: $r}' 2>/dev/null
  exit 0
fi

exit 0
