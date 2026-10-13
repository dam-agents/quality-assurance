#!/usr/bin/env bash
# pr-issues.sh <pr>: what a blind test of a pull request may know about it:
# its head commit and the issues it closes. Nothing else: not its title, body,
# commits, diff or review comments, which describe the code and not the need.
#
# Prints:
#   head: <sha>
#   issues: <owner/name>#<n> ...
#
# Exit 0 · 1 refused: the head is in a fork, or the pull request is not open
# · 3 it closes no issue · 2 GitHub could not be read
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib/config.sh"

N="${1:-}"
case "$N" in '' | *[!0-9]*) echo "usage: pr-issues.sh <pr number>" >&2; exit 2 ;; esac
SLUG="$(repo_slug)"; HOST="$(repo_host)"
[ -n "$SLUG" ] || { echo "work/CONFIG.md names no repo" >&2; exit 2; }

# shellcheck disable=SC2016
Q='query($o:String!,$r:String!,$n:Int!){repository(owner:$o,name:$r){pullRequest(number:$n){
  state headRefOid headRepository{nameWithOwner}
  closingIssuesReferences(first:20){nodes{number repository{nameWithOwner}}}}}}'
out="$(gh api graphql --hostname "$HOST" -f query="$Q" -F o="${SLUG%%/*}" -F r="${SLUG#*/}" -F n="$N" 2>&1)" ||
  { echo "GitHub could not be read: $out" >&2; exit 2; }
pr="$(printf '%s' "$out" | jq -c '.data.repository.pullRequest // empty' 2>/dev/null)"
[ -n "$pr" ] || { echo "no pull request #$N in $SLUG" >&2; exit 1; }

state="$(printf '%s' "$pr" | jq -r .state)"
head_repo="$(printf '%s' "$pr" | jq -r '.headRepository.nameWithOwner // ""')"
if [ "$(printf '%s' "$head_repo" | tr '[:upper:]' '[:lower:]')" != "$(printf '%s' "$SLUG" | tr '[:upper:]' '[:lower:]')" ]; then
  echo "refused: the head of #$N is in ${head_repo:-a deleted fork}, not in $SLUG. Only pull requests from $SLUG are built here." >&2
  exit 1
fi
[ "$state" = OPEN ] || { echo "refused: #$N is $(printf '%s' "$state" | tr '[:upper:]' '[:lower:]'), not open" >&2; exit 1; }

echo "head: $(printf '%s' "$pr" | jq -r .headRefOid)"
issues="$(printf '%s' "$pr" | jq -r '[.closingIssuesReferences.nodes[] | "\(.repository.nameWithOwner)#\(.number)"] | join(" ")')"
echo "issues: $issues"
[ -n "$issues" ] || { echo "#$N closes no issue: there is nothing to test it against" >&2; exit 3; }
exit 0
