#!/usr/bin/env bash
# test-lock.sh: one test at a time on the one platform under test.
#
# The lock is a directory, work/locks/test: mkdir takes it atomically. Its
# `owner` file names the session that holds it, the ref it tests and since
# when. It lives on the home volume and survives a restart, because the
# platform resumes an interrupted turn and that turn still holds it.
#
# A holder is dead only when the runtime says its session is not running a
# turn. A turn that ends without `release` is therefore freed by the next
# `take`, with no hook needed. A runtime that does not answer frees nothing.
#
#   take <ref>          0 taken (or already ours), 1 busy: prints who holds it
#   release <verdict>   give it back, and log one line to work/TEST.log
#   mine                0 when this session holds it
#   show                who holds it, or `free`
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib/config.sh"
. "$HERE/lib/time.sh"

LOCKS="${QA_LOCKS:-$HOME/work/locks}"
L="$LOCKS/test"
LOG="$HOME/work/TEST.log"
ME="${CLAUDE_CODE_SESSION_ID:-}"

say() { echo "test-lock: $*" >&2; }

# alive <session>: 0 running a turn · 1 not running, or unknown to the
# runtime · 2 the runtime did not answer
alive() {
  local out
  out="$(curl -fsS --max-time 5 --get \
    --data-urlencode "input={\"sessionId\":\"$1\"}" \
    "${PLATFORM_RUNTIME_URL:-}/api/trpc/sessions.list" 2>/dev/null)" || return 2
  out="$(printf '%s' "$out" | jq -r '.result.data.sessions | if type == "array" then (.[0].running // false) else "unknown" end' 2>/dev/null)"
  case "$out" in true) return 0 ;; false) return 1 ;; *) return 2 ;; esac
}

holder() { kv "$L/owner" session; }
mine() { [ -n "$ME" ] && [ -d "$L" ] && [ "$(holder)" = "$ME" ]; }

busy() {
  echo "busy testing $(kv "$L/owner" ref) since $(kv "$L/owner" since)${1:+ ($1)}"
  return 1
}

need_session() {
  [ -n "$ME" ] || { say "no \$CLAUDE_CODE_SESSION_ID: the runtime cannot tell this run is alive, so it may not hold the lock"; exit 2; }
}

case "${1:-}" in
  take)
    need_session
    ref="${2:-}"; [ -n "$ref" ] || { say "usage: take <ref>"; exit 2; }
    mkdir -p "$LOCKS" || exit 2
    if [ -d "$L" ] && ! mine; then
      if [ ! -f "$L/owner" ]; then
        # being taken right now, unless it has been so for a minute
        [ -n "$(find "$L" -maxdepth 0 -mmin +1 2>/dev/null)" ] || { busy "being taken"; exit 1; }
      else
        alive "$(holder)"
        case $? in
          0) busy; exit 1 ;;
          2) busy "the runtime did not answer, so it is not known whether that test still runs"; exit 1 ;;
        esac
      fi
      say "freed the lock of a test that is no longer running: $(kv "$L/owner" ref), session $(holder)"
      rm -rf "$L"
    fi
    if mine || mkdir "$L" 2>/dev/null; then
      since="$(kv "$L/owner" since)"
      write_kv "$L/owner" owner "session=$ME" "ref=$ref" "since=${since:-$(now)}"
      echo "taken: testing $ref"
      exit 0
    fi
    busy; exit 1 ;;
  release)
    need_session
    verdict="${2:-}"
    case "$verdict" in passed | failed | blocked | setup) ;; *) say "usage: release passed|failed|blocked|setup"; exit 2 ;; esac
    mine || { say "this session does not hold the lock"; exit 1; }
    ref="$(kv "$L/owner" ref)"; since="$(kv "$L/owner" since)"; end="$(now)"; mins=-
    if a="$(epoch "$since")" && b="$(epoch "$end")"; then mins=$(( (b - a) / 60 )); fi
    printf '%s %s ref=%s session=%s minutes=%s\n' "$end" "$verdict" "$(printf '%s' "$ref" | tr ' ' '_')" "$ME" "$mins" >> "$LOG"
    rm -rf "$L"
    echo "released"
    exit 0 ;;
  mine) mine ;;
  show)
    if [ -d "$L" ]; then cat "$L/owner" 2>/dev/null || echo "being taken"; else echo free; fi ;;
  *) say "usage: take <ref> | release <verdict> | mine | show"; exit 2 ;;
esac
