#!/usr/bin/env bash
# test-lock.sh: one test at a time, and a dead holder never blocks the next.
. "$(dirname "$0")/helpers.sh"
L() { run bash "$SCRIPTS/test-lock.sh" "$@"; }

CASE="a free lock is taken"; sandbox
L take "PR #7"; is "$RC" 0 rc; has "$OUT" "taken: testing PR #7" out
is "$(kv "$QA_LOCKS/test/owner" session)" s-me owner
L mine; is "$RC" 0 mine
done_

CASE="a live holder makes it busy"; sandbox
lock s-other main; export STUB_RUNNING=s-other
L take "PR #7"; is "$RC" 1 rc; has "$OUT" "busy testing main since 2026-10-13T08:00:00Z" out
is "$(kv "$QA_LOCKS/test/owner" session)" s-other "owner kept"
done_

CASE="a dead holder is freed"; sandbox
lock s-other main
L take "PR #7"; is "$RC" 0 rc; has "$ERR" "no longer running: main" err
is "$(kv "$QA_LOCKS/test/owner" ref)" "PR #7" ref
done_

CASE="a runtime that does not answer frees nothing"; sandbox
lock s-other main; export STUB_RUNTIME_DOWN=1
L take "PR #7"; is "$RC" 1 rc; has "$OUT" "the runtime did not answer" out
done_

CASE="taking it again keeps since and moves the ref"; sandbox
lock s-me main
L take feat/x; is "$RC" 0 rc
is "$(kv "$QA_LOCKS/test/owner" since)" 2026-10-13T08:00:00Z since
is "$(kv "$QA_LOCKS/test/owner" ref)" feat/x ref
done_

CASE="release logs the verdict and frees it"; sandbox
lock s-me "PR #7"
L release failed; is "$RC" 0 rc
[ ! -d "$QA_LOCKS/test" ] || fail "lock still there"
has "$(cat "$HOME/work/TEST.log")" "failed ref=PR_#7 session=s-me minutes=" log
done_

CASE="release by another session is refused"; sandbox
lock s-other main
L release passed; is "$RC" 1 rc; [ -d "$QA_LOCKS/test" ] || fail "lock removed"
L release maybe; is "$RC" 2 "unknown verdict"
done_

CASE="no session id holds nothing"; sandbox
unset CLAUDE_CODE_SESSION_ID
L take main; is "$RC" 2 rc; [ ! -d "$QA_LOCKS/test" ] || fail "lock taken"
done_

exit "$FAILED"
