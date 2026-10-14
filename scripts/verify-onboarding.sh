#!/usr/bin/env bash
# verify-onboarding.sh: does this instance have the shape onboarding promises?
#
# It never repairs: every FAIL carries the fix, and the caller runs it again
# until it prints PASS.
#
#   --config   work/CONFIG.md only, mid-onboarding
#   (none)     the definition checkout, work/ and CONFIG.md
#   --live     all of that, plus: GitHub reads `repo`, the runtime answers,
#              this session has a model connection to lend, and the platform
#              under test is installed and answering
#
# Exit 0 iff nothing FAILed.
set -u
export LC_ALL=C

LIVE=0; STRUCTURE=1
case "${1:-}" in
  --live) LIVE=1 ;;
  --config) STRUCTURE=0 ;;
  '') ;;
  *) echo "usage: $0 [--config|--live]" >&2; exit 2 ;;
esac

HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib/config.sh"
. "$HERE/lib/inner.sh"
WORK="$HOME/work"
CONFIG="$WORK/CONFIG.md"
KNOWN="repo model_template slack_channel"
REQUIRED="repo model_template"
TEMPLATES="anthropic anthropic-oauth openai ibm-litellm curve-bender bedrock"

CHECKS=0; FAILS=0; WARNS=0
ok()   { CHECKS=$((CHECKS + 1)); printf 'ok   %s: %s\n' "$1" "$2"; }
fail() { CHECKS=$((CHECKS + 1)); FAILS=$((FAILS + 1)); printf 'FAIL %s: %s: fix: %s\n' "$1" "$2" "$3"; }
warn() { WARNS=$((WARNS + 1)); printf 'warn %s: %s\n' "$1" "$2"; }

# unknown_keys <file>: the `- key:` bullets nothing reads, space-separated
unknown_keys() {
  local k
  grep -oE '^[-*][[:space:]]*[A-Za-z0-9_]+[[:space:]]*:' "$1" | sed -E 's/^[-*][[:space:]]*//; s/[[:space:]]*:$//' |
    tr '[:upper:]' '[:lower:]' | sort -u | while read -r k; do
      case " $KNOWN " in *" $k "*) ;; *) printf '%s ' "$k" ;; esac
    done
}

# ------------------------------------------------------------------ CONFIG
CFG_FIX="ONBOARDING.md → 3. Write it down"
REPO="$(cfg repo)"; SLUG="$(repo_slug)"; HOST="$(repo_host)"
if [ ! -f "$CONFIG" ]; then
  fail config "work/CONFIG.md is missing" "write it: $CFG_FIX"
else
  for k in $REQUIRED; do
    if [ -n "$(cfg "$k")" ]; then ok "config.$k" "$(cfg "$k")"
    else fail "config.$k" "missing" "add \`- $k: <value>\`: $CFG_FIX"; fi
  done
  if [ -n "$REPO" ] && ! printf '%s' "$REPO" | grep -qE '^([A-Za-z0-9.-]+/)?[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$'; then
    fail config.repo "'$REPO' is not owner/name" "write it as owner/name: $CFG_FIX"
  fi
  sc="$(cfg slack_channel)"
  if [ -z "$sc" ]; then ok config.slack_channel "none: Slack orders nothing"
  elif printf '%s' "$sc" | grep -qE '^[CGD][A-Z0-9]{6,}$'; then ok config.slack_channel "$sc"
  else fail config.slack_channel "'$sc' is not a Slack chat id" "use the id describe_channel lists, e.g. C0123ABCD: $CFG_FIX"; fi
  t="$(cfg model_template)"
  case " $TEMPLATES " in *" $t "*) ;; *) [ -z "$t" ] || warn config.model_template "'$t' is not a model template this definition knows: fine if the platform has it" ;; esac
  unknown="$(unknown_keys "$CONFIG")"
  if [ -n "$unknown" ]; then fail config.keys "unknown: $unknown" "remove them, nothing reads them: $CFG_FIX"
  else ok config.keys "only known keys"; fi
fi

# --------------------------------------------------------------- structure
if [ "$STRUCTURE" = 1 ]; then
  [ -f "$HOME/.quality-assurance-onboarded" ] && ok sentinel "onboarded" ||
    fail sentinel "\$HOME/.quality-assurance-onboarded is missing" "ONBOARDING.md → 5. Finish"
  [ -f "$WORK/VERSION" ] && ok version "adopted $(head -1 "$WORK/VERSION")" ||
    fail version "work/VERSION is missing" "head -1 \$HOME/VERSION > \$HOME/work/VERSION"
  [ -f "$WORK/AGENTS.md" ] && ok pointer "work/AGENTS.md" ||
    fail pointer "work/AGENTS.md is missing" "ONBOARDING.md → 3. Write it down"
  CO="$(checkout_dir)"
  if [ -e "$CO/.git" ]; then
    url="$(git -C "$CO" remote get-url origin 2>/dev/null)"
    case "$(printf '%s' "$url" | tr '[:upper:]' '[:lower:]')" in
      *"$(printf '%s' "$SLUG" | tr '[:upper:]' '[:lower:]')"|*"$(printf '%s' "$SLUG" | tr '[:upper:]' '[:lower:]')".git) ok checkout "${CO#"$HOME"/} from $url" ;;
      *) fail checkout "${CO#"$HOME"/} is a clone of $url, not $SLUG" "move it aside; ensure-env.sh clones $SLUG" ;;
    esac
  else
    fail checkout "no checkout at ${CO#"$HOME"/}" "ensure-env.sh clones it: ONBOARDING.md → 4. Install"
  fi
  [ -f "$HOME/.claude/skills/qa-test/SKILL.md" ] && ok skills "qa-test loads" ||
    fail skills "qa-test does not resolve through ~/.claude/skills" "bash \$HOME/scripts/harness/claude-code/install.sh"
fi

# -------------------------------------------------------------------- live
if [ "$LIVE" = 1 ]; then
  if [ -n "$SLUG" ] && gh api --hostname "$HOST" "repos/$SLUG" --jq .full_name >/dev/null 2>&1; then
    ok github "reads $SLUG"
  else
    fail github "cannot read $SLUG" "the GitHub connection must read the repository (README)"
  fi
  [ -n "${PLATFORM_PROVIDER:-}" ] && ok model "this session's model connection is $PLATFORM_PROVIDER" ||
    fail model "\$PLATFORM_PROVIDER is not set" "give this agent a model connection in its settings"
  if curl -fsS --max-time 5 --get --data-urlencode 'input={"sessionId":"-"}' \
      "${PLATFORM_RUNTIME_URL:-}/api/trpc/sessions.list" >/dev/null 2>&1; then
    ok runtime "answers: the test lock can tell a dead test from a live one"
  else
    fail runtime "does not answer at \$PLATFORM_RUNTIME_URL" "an operator issue: the lock frees nothing while it is down"
  fi
  state="$(kv "$WORK/ENV.md" state)"
  if [ "$state" = ready ]; then ok env "$(kv "$WORK/ENV.md" ref) at $(kv "$WORK/ENV.md" sha | cut -c1-12)"
  else fail env "work/ENV.md says ${state:-nothing is installed}" "ONBOARDING.md → 4. Install"; fi
  if k3s_up && ui_up; then ok platform "answers at $UI_URL"
  else fail platform "does not answer at $UI_URL" "ensure-env.sh starts it again: docs/environment.md"; fi
fi

echo
if [ "$FAILS" -eq 0 ]; then echo "PASS: $CHECKS checks, $WARNS warnings"; exit 0; fi
echo "FAIL: $FAILS of $CHECKS checks failed, $WARNS warnings"; exit 1
