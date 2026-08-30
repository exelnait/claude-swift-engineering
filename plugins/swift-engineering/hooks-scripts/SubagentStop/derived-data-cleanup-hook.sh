#!/usr/bin/env bash
#
# derived-data-cleanup-hook.sh — reclaim disk after an agent / turn finishes.
#
# Wired (see ../../hooks/hooks.json) to run on SubagentStop and Stop — i.e. every
# time a subagent or a turn finishes, so agents "clean up after themselves". It
# sweeps the per-build DerivedData scratch trees the Halm workflow leaves under
# /private/tmp/halm-* (each 200 MB–1 GB; they otherwise pile up across concurrent
# agent sessions until the disk fills — a real incident left 35 trees ≈ 90 GB and
# silently corrupted an xcresult bundle mid-run).
#
# HARDCODED to the Halm workflow's `halm-*` scratch namespace on purpose (this is a
# personal fork). On any project that does NOT use /private/tmp/halm-* the sweep
# simply finds nothing and is a no-op, so it is safe to leave always-on.
#
# SAFETY (load-bearing — many agents build in the same checkout at once):
#   • AGE-GATED: a tree with ANY file modified within HALM_DD_MAX_AGE_MIN minutes
#     (default 90) is left ALONE — an in-flight build of a concurrent session is
#     never deleted. (A just-finished tree is still fresh, so it is reclaimed later
#     once it goes idle, or reused by the next build — not yanked out from under
#     anything.)
#   • Never touches ~/Library/Developer/Xcode/DerivedData (Xcode's own cache for
#     the user's interactive builds).
#   • Aborts if `find -mmin` is unavailable rather than guess.
#   • A single mkdir-lock keeps concurrent agents from all sweeping at once.
#   • NON-BLOCKING: always exits 0, never blocks the agent / turn from finishing.
#
# Manual use: derived-data-cleanup-hook.sh [--verbose]
#   HALM_DD_MAX_AGE_MIN=0  remove ALL halm-* trees regardless of age (a deliberate
#                          full sweep; do NOT use while other sessions are building).
#
set -uo pipefail

# Drain the hook's JSON payload on stdin (we don't need it); fail-open.
[ -t 0 ] || cat >/dev/null 2>&1 || true

verbose=0
[ "${1:-}" = "--verbose" ] && verbose=1
log() { [ "$verbose" -eq 1 ] && printf '%s\n' "$*" >&2; return 0; }

age_min="${HALM_DD_MAX_AGE_MIN:-90}"
case "$age_min" in '' | *[!0-9]*) age_min=90 ;; esac   # non-numeric → default

# --- capability probe: never delete on a broken activity check -----------------
probe="$(mktemp -d 2>/dev/null)" || exit 0
if ! find "$probe" -mmin -1 >/dev/null 2>&1; then
  rmdir "$probe" 2>/dev/null || true
  log "derived-data-cleanup: 'find -mmin' unavailable — skipping for safety"
  exit 0
fi
rmdir "$probe" 2>/dev/null || true

# --- single-sweeper lock (steal only if a prior sweep died > 30 min ago) --------
lockdir="/tmp/.halm-dd-sweep.lock"
if [ -d "$lockdir" ] && [ -z "$(find "$lockdir" -maxdepth 0 -mmin -30 2>/dev/null)" ]; then
  rmdir "$lockdir" 2>/dev/null || true
fi
if ! mkdir "$lockdir" 2>/dev/null; then
  log "derived-data-cleanup: another sweep is in progress — skipping"
  exit 0
fi
trap 'rmdir "$lockdir" 2>/dev/null || true' EXIT

# --- resolve tmp roots (dedupe: /tmp -> /private/tmp on macOS) ------------------
roots=""
for d in /private/tmp /tmp; do
  [ -d "$d" ] || continue
  rp="$(cd "$d" 2>/dev/null && pwd -P)" || continue
  case " $roots " in *" $rp "*) : ;; *) roots="$roots $rp" ;; esac
done

removed=0
kept=0
for root in $roots; do
  for tree in "$root"/halm-*; do
    [ -d "$tree" ] || continue                                # unmatched glob / non-dir
    case "$tree" in /private/tmp/halm-* | /tmp/halm-*) : ;; *) continue ;; esac
    if [ "$age_min" -gt 0 ] &&
      [ -n "$(find "$tree" -mmin "-$age_min" -print 2>/dev/null | head -n1)" ]; then
      kept=$((kept + 1))
      log "keep  $tree  (active within ${age_min}m)"
      continue
    fi
    if rm -rf "$tree" 2>/dev/null; then
      removed=$((removed + 1))
      log "swept $tree"
    fi
  done
done

log "derived-data-cleanup: removed $removed, kept $kept active (idle threshold ${age_min}m)"
exit 0
