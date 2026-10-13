#!/usr/bin/env bash
# cleanup.sh: deletes what tests made, and nothing else.
. "$(dirname "$0")/helpers.sh"
C() { run bash "$SCRIPTS/cleanup.sh"; }

CASE="deletes qa- agents and connections, keeps the rest"; sandbox; origin; lock s-me main; touch "$HOME/ui.up"
echo '[{"id":"a1","name":"qa-202610131200-chat"},{"id":"a2","name":"my-agent"}]' > "$HOME/agents.json"
echo '[{"id":"c1","name":"outer-model"},{"id":"c2","name":"qa-202610131200-gh"},{"id":"c3","name":"github"}]' > "$HOME/conns.json"
C; is "$RC" 0 rc; has "$OUT" "deleted 2" out
has "$(calls dam)" "agent delete a1 --yes" a1; has "$(calls dam)" "connection disconnect c2" c2
lacks "$(calls dam)" a2 "kept my-agent"; lacks "$(calls dam)" "disconnect c1" "kept outer-model"; lacks "$(calls dam)" c3 "kept github"
done_

CASE="a failed delete is reported"; sandbox; origin; lock s-me main; touch "$HOME/ui.up"
echo '[{"id":"a1","name":"qa-1-x"}]' > "$HOME/agents.json"; export STUB_DELETE_FAIL=a1
C; is "$RC" 1 rc; has "$ERR" "could not delete agent a1" err
done_

CASE="refused without the lock"; sandbox; origin
C; is "$RC" 2 rc; is "$(calls dam)" "" "no calls"
done_

CASE="nothing to clean when the platform is down"; sandbox; origin; lock s-me main
C; is "$RC" 0 rc; is "$(calls dam)" "" "no calls"
done_

exit "$FAILED"
