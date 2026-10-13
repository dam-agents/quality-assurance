#!/usr/bin/env bash
# cleanup.sh: delete what tests created on the platform under test: every
# agent and connection whose name starts with `qa-`. Never `outer-model`, the
# setup's model connection. Only under the test lock.
#
# A test runs it at its start, for whatever a failed test before it kept, and
# at its end unless the test failed: what a failed test made stays for a
# person to look at until the next test.
#
# Exit 0 clean · 1 something could not be deleted (listed on stderr)
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib/config.sh"
. "$HERE/lib/inner.sh"

say() { echo "cleanup: $*" >&2; }

bash "$HERE/test-lock.sh" mine || { say "take the test lock first"; exit 2; }
ui_up || { say "the platform under test does not answer: nothing to clean"; exit 0; }
DAM_TOKEN="$(inner_token)" || { say "could not log in as $DEV_USER"; exit 1; }
export DAM_TOKEN

rc=0; n=0
pick() { jq -r --arg p "$QA_PREFIX" --arg keep "$MODEL_CONNECTION" '.[] | select((.name // "") | startswith($p)) | select(.name != $keep) | .id'; }

agents="$(dam agent list --json 2>/dev/null)" || { say "could not list agents"; exit 1; }
for id in $(printf '%s' "$agents" | pick); do
  if dam agent delete "$id" --yes >/dev/null 2>&1; then n=$((n + 1)); else say "could not delete agent $id"; rc=1; fi
done
conns="$(dam connection list --json 2>/dev/null)" || { say "could not list connections"; exit 1; }
for id in $(printf '%s' "$conns" | pick); do
  if dam connection disconnect "$id" >/dev/null 2>&1; then n=$((n + 1)); else say "could not delete connection $id"; rc=1; fi
done
echo "deleted $n"
exit "$rc"
