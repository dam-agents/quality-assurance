#!/usr/bin/env bash
# inner-setup.sh: the setup the platform under test needs before a test, done
# the same way every time. Idempotent: ensure-env.sh runs it after every
# install, and it is safe to run again by hand.
#
#   1. build the dam CLI from the checkout, at the ref under test
#   2. log in as the dev user, and accept the terms of use
#   3. the model connection `outer-model`: the template `model_template` names,
#      its value the placeholder of this agent's own model connection,
#      `platform:conn:$PLATFORM_PROVIDER`. The real key never enters the
#      sandbox: the inner gateway sends the placeholder, and this agent's own
#      gateway swaps it for the key on the way out.
#
# Exit 0 ready · 1 failed (the reason on stderr)
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/lib/config.sh"
. "$HERE/lib/inner.sh"

say() { echo "inner-setup: $*" >&2; }

CO="$(checkout_dir)"
TEMPLATE="$(cfg model_template)"
[ -e "$CO/.git" ] || { say "no checkout at $CO: run ensure-env.sh"; exit 1; }
[ -n "$TEMPLATE" ] || { say "work/CONFIG.md names no model_template (ONBOARDING.md → 2. Ask)"; exit 1; }
[ -n "${PLATFORM_PROVIDER:-}" ] || { say "\$PLATFORM_PROVIDER is not set: this session has no model connection to lend"; exit 1; }
ui_up || { say "the platform under test does not answer at $UI_URL"; exit 1; }

LOGS="$HOME/work/logs"; mkdir -p "$LOGS"
if ! (cd "$CO" && low mise run //packages/cli:build) > "$LOGS/cli-build.log" 2>&1; then
  say "the dam CLI did not build: the end of work/logs/cli-build.log:"; tail -20 "$LOGS/cli-build.log" >&2; exit 1
fi

DAM_TOKEN="$(inner_token)" || { say "could not log in as $DEV_USER at http://$KC_HOST:$KC_PORT"; exit 1; }
export DAM_TOKEN
dam terms accept --yes >/dev/null 2>&1 || say "could not accept the terms of use (already accepted on some versions): carrying on"

want="platform:conn:$PLATFORM_PROVIDER"
existing="$(dam connection list --json 2>/dev/null)" || { say "could not list connections"; exit 1; }
id="$(printf '%s' "$existing" | jq -r --arg n "$MODEL_CONNECTION" 'map(select(.name == $n)) | first | .id // empty')"
if [ -n "$id" ]; then
  # The value cannot be read back, so it is set again: the operator may have
  # moved this agent to another model connection since.
  dam connection update "$id" --value "$want" >/dev/null 2>&1 ||
    { dam connection disconnect "$id" >/dev/null 2>&1 && id=""; } ||
    { say "could not refresh $MODEL_CONNECTION"; exit 1; }
fi
if [ -z "$id" ]; then
  out="$(dam connection connect "$TEMPLATE" --name "$MODEL_CONNECTION" --value "$want" --json 2>&1)" ||
    { say "could not create $MODEL_CONNECTION from template $TEMPLATE: $out"; exit 1; }
  id="$(printf '%s' "$out" | jq -r '.id // empty' 2>/dev/null)"
fi
echo "ready: $UI_URL, user $DEV_USER, model connection $MODEL_CONNECTION ($TEMPLATE${id:+, $id})"
