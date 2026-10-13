#!/usr/bin/env bash
# ensure-env.sh: does only what is missing, resets data only on a new ref.
. "$(dirname "$0")/helpers.sh"
E() { run bash "$SCRIPTS/ensure-env.sh" "$@"; }
env_() { kv "$HOME/work/ENV.md" "$1"; }
installed() {   # installed <ref> <branch>: as a finished ensure-env.sh leaves it
  write_kv "$HOME/work/ENV.md" ENV "ref=$1" "sha=$(sha_of "$2")" state=ready at=x data_since=2026-10-01T00:00:00Z
  touch "$HOME/k3s.up" "$HOME/ui.up"
}

CASE="refused without the lock"; sandbox; origin
E main; is "$RC" 2 rc; has "$ERR" "take the test lock first" err; is "$(calls mise)" "" "no mise"
done_

CASE="first install"; sandbox; origin; lock s-me main
E main; is "$RC" 0 rc; has "$OUT" "ready: main at" out
is "$(calls mise | grep -E '^(install|run cluster:)' | tr '\n' ,)" "install,run cluster:install," "tools first, then install"
is "$(sort -u "$HOME/mise.datadirs")" "$HOME/.local/share/mise" "tools under HOME, never the shared tools folder"
is "$(env_ ref)" main ref; is "$(env_ sha)" "$(sha_of main)" sha; is "$(env_ state)" ready state
is "$(git -C "$HOME/work/platform" rev-parse HEAD)" "$(sha_of main)" "checkout at main"
has "$(calls dam)" "connection connect anthropic --name outer-model --value platform:conn:conn-outer" "model connection"
done_

CASE="same commit, answering: nothing to do"; sandbox; origin; lock s-me main; installed main main
E main; is "$RC" 0 rc
lacks "$(calls mise)" cluster: "no cluster task"; is "$(calls mise | grep -c '^install')" 0 "no tools install"
is "$(env_ data_since)" 2026-10-01T00:00:00Z "data kept"
done_

CASE="same ref, new commit: install, data kept"; sandbox; origin; lock s-me feat/x; installed feat/x main
E feat/x; is "$RC" 0 rc
has "$(calls mise)" "run cluster:install" install; lacks "$(calls mise)" uninstall "no uninstall"
is "$(env_ sha)" "$(sha_of feat/x)" sha; is "$(env_ data_since)" 2026-10-01T00:00:00Z "data kept"
done_

CASE="new ref: uninstall, then install"; sandbox; origin; lock s-me feat/x; installed main main
E feat/x; is "$RC" 0 rc
is "$(calls mise | grep -E '^(install|run cluster:)' | tr '\n' ,)" "run cluster:uninstall,install,run cluster:install," order
lacks "$(env_ data_since)" 2026-10-01 "data reset"
done_

CASE="after a restart: back up as it was, then on"; sandbox; origin; lock s-me main; installed main main
rm -f "$HOME/k3s.up" "$HOME/ui.up"
E main; is "$RC" 0 rc
is "$(calls mise | grep cluster: | tr '\n' ,)" "run cluster:helm," "restart only"
done_

CASE="a pull request"; sandbox; origin; lock s-me "PR #7"; pr acme/platform
E --pr 7; is "$RC" 0 rc; has "$OUT" "ready: PR #7 at" out
is "$(env_ ref)" "PR #7" ref; is "$(git -C "$HOME/work/platform" rev-parse HEAD)" "$(sha_of feat/x)" "checkout at head"
done_

CASE="a fork is refused before anything is built"; sandbox; origin; lock s-me "PR #7"; pr someone/platform
E --pr 7; is "$RC" 2 rc; is "$(calls mise)" "" "no mise"
done_

CASE="a branch that does not exist"; sandbox; origin; lock s-me nope
E nope; is "$RC" 2 rc; has "$ERR" "no branch nope" err
done_

CASE="a failed install is recorded"; sandbox; origin; lock s-me main; export STUB_INSTALL_FAIL=1
E main; is "$RC" 1 rc; has "$ERR" "image import failed" "log tail"
is "$(env_ state)" failed state
done_

CASE="tools that fail to install stop before the install"; sandbox; origin; lock s-me main; export STUB_TOOLS_FAIL=1
E main; is "$RC" 1 rc; has "$ERR" "failed to install tools" "log tail"
lacks "$(calls mise)" "run cluster:install" "no install"; is "$(env_ state)" failed state
done_

CASE="the model connection is refreshed, not duplicated"; sandbox; origin; lock s-me main; installed main main
echo '[{"id":"conn-1","name":"outer-model"}]' > "$HOME/conns.json"
E main; is "$RC" 0 rc
has "$(calls dam)" "connection update conn-1 --value platform:conn:conn-outer" update
lacks "$(calls dam)" "connection connect" "no second connection"
done_

CASE="no model connection to lend"; sandbox; origin; lock s-me main; unset PLATFORM_PROVIDER
E main; is "$RC" 1 rc; has "$ERR" PLATFORM_PROVIDER err; is "$(env_ state)" failed state
done_

exit "$FAILED"
