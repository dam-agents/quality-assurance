#!/usr/bin/env bash
# ensure-env.sh: put the platform under test at a ref, ready to test.
# Idempotent: run it before every test, and it does only what is missing.
#
#   ensure-env.sh <branch>     a branch of `repo`
#   ensure-env.sh --pr <n>     an open pull request whose head is in `repo`
#
# Only under the test lock (test-lock.sh take). What it does, in order:
#
#   1. k3s stopped (the sandbox restarted): start the platform again as it was,
#      at the commit work/ENV.md records, with `cluster:helm`, which starts
#      k3s and rebuilds nothing.
#   2. the checkout, detached at the ref's commit.
#   3. one of:
#      - nothing installed yet           → cluster:install
#      - another ref than last time      → cluster:uninstall, then cluster:install:
#                                          the platform's data starts empty; k3s
#                                          and the image cache stay
#      - the same ref, a newer commit    → cluster:install, data kept
#      - the same commit, not answering  → cluster:install
#      - the same commit, answering      → nothing
#      Before an install, `mise install` puts the checkout's tools in place in
#      one process, under HOME (lib/inner.sh), so a tool that fails to install
#      stops here with its own error rather than inside one of the install's
#      parallel builds.
#   4. inner-setup.sh.
#
# The commands it runs are the platform's own (its mise tasks), from the
# checkout. Their output goes to work/logs/; on a failure the end of the log is
# printed. An install takes long: run this as a background task.
#
# Exit 0 ready (prints `ready: <ref> at <sha>`) · 1 failed · 2 refused
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib/config.sh"
. "$HERE/lib/time.sh"
. "$HERE/lib/inner.sh"

say() { echo "ensure-env: $*" >&2; }

ENV_FILE="$HOME/work/ENV.md"
LOGS="$HOME/work/logs"
CO="$(checkout_dir)"
SLUG="$(repo_slug)"; HOST="$(repo_host)"

PR=""; BRANCH=""
case "${1:-}" in
  --pr) PR="${2:-}"; case "$PR" in '' | *[!0-9]*) say "usage: ensure-env.sh <branch> | --pr <n>"; exit 2 ;; esac ;;
  '' | -*) say "usage: ensure-env.sh <branch> | --pr <n>"; exit 2 ;;
  *) BRANCH="$1" ;;
esac
REF="${PR:+PR #$PR}${BRANCH}"

bash "$HERE/test-lock.sh" mine || { say "take the test lock first: test-lock.sh take \"$REF\""; exit 2; }
[ -n "$SLUG" ] || { say "work/CONFIG.md names no repo"; exit 2; }
mkdir -p "$LOGS"

# run <name> <command...>: in the checkout, output to work/logs/<name>.log
run() {
  local name="$1"; shift
  echo "$(now) $name: $*" >&2
  if (cd "$CO" && "$@") > "$LOGS/$name.log" 2>&1; then return 0; fi
  say "$name failed: the end of work/logs/$name.log:"; tail -30 "$LOGS/$name.log" >&2
  return 1
}

record() {   # record <state>: work/ENV.md
  write_kv "$ENV_FILE" ENV "ref=$1" "sha=$2" "state=$3" "at=$(now)" "data_since=$4"
}

# ---------------------------------------------------------------- checkout
if [ ! -e "$CO/.git" ]; then
  git clone -q --filter=blob:none "https://$HOST/$SLUG" "$CO" || { say "could not clone $SLUG"; exit 1; }
fi

HAVE_REF="$(kv "$ENV_FILE" ref)"; HAVE_SHA="$(kv "$ENV_FILE" sha)"; HAVE_STATE="$(kv "$ENV_FILE" state)"
DATA_SINCE="$(kv "$ENV_FILE" data_since)"

# 1. after a restart, bring back what was there before moving anywhere
if [ -n "$HAVE_SHA" ] && [ "$HAVE_STATE" = ready ] && ! k3s_up; then
  if git -C "$CO" checkout -qf --detach "$HAVE_SHA" 2>/dev/null; then
    mise trust -q "$CO" >/dev/null 2>&1
    run restart mise run cluster:helm || say "could not start the platform as it was: the install below starts it"
  fi
fi

# 2. the ref's commit
if [ -n "$PR" ]; then
  info="$(bash "$HERE/pr-issues.sh" "$PR")"; rc=$?
  case "$rc" in 0 | 3) ;; 1) exit 2 ;; *) exit 1 ;; esac
  WANT_SHA="$(printf '%s\n' "$info" | sed -n 's/^head: //p')"
  git -C "$CO" fetch -q origin "pull/$PR/head" || { say "could not fetch pull/$PR/head"; exit 1; }
  [ "$(git -C "$CO" rev-parse FETCH_HEAD)" = "$WANT_SHA" ] ||
    { say "pull/$PR/head is not at $WANT_SHA: a push landed meanwhile, run this again"; exit 1; }
else
  git -C "$CO" fetch -q origin "refs/heads/$BRANCH" 2>/dev/null || { say "no branch $BRANCH in $SLUG"; exit 2; }
  WANT_SHA="$(git -C "$CO" rev-parse FETCH_HEAD)"
fi
git -C "$CO" checkout -qf --detach "$WANT_SHA" || { say "could not check out $WANT_SHA"; exit 1; }
mise trust -q "$CO" >/dev/null 2>&1

# 3. install what is missing
SHORT="$(printf '%s' "$WANT_SHA" | cut -c1-12)"
if [ -z "$HAVE_REF" ]; then
  why="first install"
elif [ "$HAVE_REF" != "$REF" ]; then
  why="new ref (was $HAVE_REF): data reset"
elif [ "$HAVE_SHA" != "$WANT_SHA" ]; then
  why="new commit on $REF (was $(printf '%s' "$HAVE_SHA" | cut -c1-12)): data kept"
elif [ "$HAVE_STATE" != ready ] || ! ui_up; then
  why="not answering: reinstall, data kept"
else
  why=""
fi

if [ -n "$why" ]; then
  echo "$REF at $SHORT: $why" >&2
  case "$why" in
    "new ref"*)
      if k3s_up; then run uninstall mise run cluster:uninstall || exit 1; fi
      DATA_SINCE="$(now)" ;;
    "first install") DATA_SINCE="$(now)" ;;
  esac
  record "$REF" "$WANT_SHA" installing "$DATA_SINCE"
  run tools mise install || { record "$REF" "$WANT_SHA" failed "$DATA_SINCE"; exit 1; }
  run install mise run cluster:install || { record "$REF" "$WANT_SHA" failed "$DATA_SINCE"; exit 1; }
  for _ in $(seq 1 30); do ui_up && break; sleep 10; done
  ui_up || { say "installed, but $UI_URL does not answer after 5 minutes"; record "$REF" "$WANT_SHA" failed "$DATA_SINCE"; exit 1; }
fi

# 4. the setup a test needs
bash "$HERE/inner-setup.sh" || { record "$REF" "$WANT_SHA" failed "$DATA_SINCE"; exit 1; }
record "$REF" "$WANT_SHA" ready "${DATA_SINCE:-$(now)}"
echo "ready: $REF at $SHORT"
