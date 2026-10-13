#!/usr/bin/env bash
# pr-issues.sh: a blind test learns the head and the closing issues, nothing else.
. "$(dirname "$0")/helpers.sh"
P() { run bash "$SCRIPTS/pr-issues.sh" "$@"; }

CASE="an open pull request from the repository"; sandbox
pr acme/platform OPEN '[{"number":12,"repository":{"nameWithOwner":"acme/platform"}},{"number":3,"repository":{"nameWithOwner":"acme/kits"}}]'
P 7; is "$RC" 0 rc
has "$OUT" "head: abc" head; has "$OUT" "issues: acme/platform#12 acme/kits#3" issues
lacks "$(calls gh)" "body" "asks for no body"; lacks "$(calls gh)" "title" "asks for no title"
done_

CASE="a fork is refused"; sandbox
pr someone/platform; P 7; is "$RC" 1 rc; has "$ERR" "is in someone/platform" err; lacks "$OUT" head: out
done_

CASE="a deleted fork is refused"; sandbox
pr ""; P 7; is "$RC" 1 rc
done_

CASE="a merged pull request is refused"; sandbox
pr acme/platform MERGED; P 7; is "$RC" 1 rc; has "$ERR" "merged" err
done_

CASE="no closing issue"; sandbox
pr acme/platform OPEN '[]'; P 7; is "$RC" 3 rc; has "$ERR" "closes no issue" err; has "$OUT" "head: " "still names the head"
done_

CASE="GitHub down"; sandbox
export STUB_GH_FAIL=1; P 7; is "$RC" 2 rc
done_

CASE="not a number"; sandbox
P abc; is "$RC" 2 rc
done_

exit "$FAILED"
