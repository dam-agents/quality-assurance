#!/usr/bin/env bash
# env-wait.sh: wait, inside the turn, for an ensure-env.sh that runs in the
# background. A Slack turn ends when you stop, and a result that arrives after
# it has no thread to land in, so a test asked in Slack stays in its turn until
# the environment is ready or has failed (docs/slack.md).
#
# Blocks for up to about 9 minutes, under the harness's 10-minute tool limit.
#
# Exit 0: ensure-env.sh no longer runs; prints the state work/ENV.md records
# · 3: it still runs; run this again
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib/config.sh"

WAIT_FOR="${QA_WAIT_FOR:-540}"
POLL="${QA_WAIT_POLL:-15}"
ENV_FILE="$HOME/work/ENV.md"

running() { pgrep -f "scripts/ensure-env.sh" >/dev/null 2>&1; }

end=$((SECONDS + WAIT_FOR))
while running; do
  if [ "$SECONDS" -ge "$end" ]; then
    echo "still running: $(kv "$ENV_FILE" ref) is $(kv "$ENV_FILE" state); run env-wait.sh again"
    exit 3
  fi
  sleep "$POLL"
done
echo "done: $(kv "$ENV_FILE" ref) at $(kv "$ENV_FILE" sha | cut -c1-12) is $(kv "$ENV_FILE" state)"
