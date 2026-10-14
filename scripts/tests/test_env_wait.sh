#!/usr/bin/env bash
# env-wait.sh: a Slack turn waits for the background install inside the turn.
. "$(dirname "$0")/helpers.sh"
W() { run bash "$SCRIPTS/env-wait.sh"; }
export QA_WAIT_POLL=1

CASE="nothing running: done at once, with the recorded state"; sandbox
write_kv "$HOME/work/ENV.md" ENV ref=main sha=0123456789abcdef state=ready
W; is "$RC" 0 rc; has "$OUT" "done: main at 0123456789ab is ready" out
done_

CASE="still running when the wait runs out"; sandbox
write_kv "$HOME/work/ENV.md" ENV "ref=PR #7" state=installing
touch "$HOME/ensure.running"; export QA_WAIT_FOR=1
W; is "$RC" 3 rc; has "$OUT" "still running: PR #7 is installing" out
unset QA_WAIT_FOR
done_

CASE="the install ends during the wait"; sandbox
write_kv "$HOME/work/ENV.md" ENV ref=main state=installing
touch "$HOME/ensure.running"
( sleep 2; write_kv "$HOME/work/ENV.md" ENV ref=main state=failed; rm -f "$HOME/ensure.running" ) &
W; wait; is "$RC" 0 rc; has "$OUT" "is failed" out
done_

exit "$FAILED"
