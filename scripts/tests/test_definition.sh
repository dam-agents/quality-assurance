#!/usr/bin/env bash
# The definition agrees with itself: the places that name config keys say the
# same thing, and onboarding writes a CONFIG.md the verifier accepts.
. "$(dirname "$0")/helpers.sh"
ROOT="$(cd "$SCRIPTS/.." && pwd)"

onb="$(sed -n '/^```markdown$/,/^```$/p' "$ROOT/ONBOARDING.md" | grep -oE '^- [a-z_]+:' |
  sed 's/^- //; s/:$//' | sort)"
known="$(sed -n 's/^KNOWN="\(.*\)"$/\1/p' "$ROOT/scripts/verify-onboarding.sh" | tr ' ' '\n' | grep . | sort)"

CASE="the verifier knows exactly the keys onboarding writes"
[ -n "$onb" ] || fail "found no keys in ONBOARDING's example"
is "$known" "$onb" "KNOWN against ONBOARDING"

CASE="CLAUDE.md documents every key"
section="$(sed -n '/^## Runtime configuration/,/^## Requests/p' "$ROOT/CLAUDE.md")"
for k in $onb; do
  case "$section" in *"\`$k\`"*) ;; *) fail "\`$k\` is not in CLAUDE.md → Runtime configuration" ;; esac
done

CASE="the verifier accepts the config onboarding writes"; sandbox
run bash "$SCRIPTS/verify-onboarding.sh" --config; is "$RC" 0 rc; has "$OUT" PASS out
printf -- '- slots: 3\n' >> "$HOME/work/CONFIG.md"
run bash "$SCRIPTS/verify-onboarding.sh" --config; is "$RC" 1 "unknown key"; has "$OUT" "unknown: slots" out
rm "$HOME/work/CONFIG.md"
run bash "$SCRIPTS/verify-onboarding.sh" --config; is "$RC" 1 "no config"
done_

CASE="config.sh puts mise shims after real binaries, keeping the rest in order"
got="$(PATH="/a:/x/mise/shims:/b:/usr/bin:/bin" bash -c '. "$1"; printf %s "$PATH"' _ "$SCRIPTS/lib/config.sh")"
is "$got" "/a:/b:/usr/bin:/bin:/x/mise/shims" "shims last"

exit "$FAILED"
