#!/usr/bin/env bash
# helpers.sh: sandbox and assertions shared by the test files. Sourced.
set -u

TESTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$(cd "$TESTS/.." && pwd)"
FAILED=0

# A mise shim resolves its tool through config under $HOME, which the sandbox
# replaces, so link the real binary once while $HOME is still the real one.
TOOLS="$(mktemp -d)"
trap 'rm -rf "$TOOLS"' EXIT
unshimmed() {
  local d IFS=:
  for d in $PATH; do
    case "$d" in */shims*) continue ;; esac
    [ -x "$d/$1" ] && { echo "$d/$1"; return 0; }
  done
  command -v mise >/dev/null 2>&1 && mise which "$1" 2>/dev/null
}
case "$(command -v jq)" in
  */shims/*) real="$(unshimmed jq)" && ln -s "$real" "$TOOLS/jq" ;;
esac
export PATH="$TESTS/bin:$TOOLS:$PATH"
. "$SCRIPTS/lib/config.sh"   # the PATH every script runs with

# sandbox: a fresh $HOME with a configured work/ and empty stub traces
sandbox() {
  export HOME; HOME="$(mktemp -d)"
  export STUB_DIR="$HOME"
  mkdir -p "$HOME/work"
  cat > "$HOME/work/CONFIG.md" <<'CFG'
Set up during onboarding.

- repo: acme/platform
- model_template: anthropic

## Bounds

- None.
CFG
  export QA_LOCKS="$HOME/work/locks" CLAUDE_CODE_SESSION_ID=s-me PLATFORM_PROVIDER=conn-outer
  export PLATFORM_RUNTIME_URL="http://127.0.0.1:9"
  unset STUB_RUNNING STUB_RUNTIME_DOWN STUB_KC_DOWN STUB_PR STUB_GH_FAIL STUB_REPO_NAME STUB_INSTALL_FAIL \
    STUB_DELETE_FAIL DAM_TOKEN
}

# origin: work/platform cloned from a local bare origin: `main` with one
# commit, `feat/x` one commit ahead, and pull request 7 at feat/x's head
origin() {
  local seed; seed="$(mktemp -d)"
  git init -q --bare -b main "$HOME/platform.git"
  git init -q -b main "$seed/s" && echo hello > "$seed/s/README.md"
  gitc -C "$seed/s" add -A && gitc -C "$seed/s" commit -qm init
  git -C "$seed/s" push -q "$HOME/platform.git" main
  git -C "$seed/s" checkout -qb feat/x && echo x > "$seed/s/x" && gitc -C "$seed/s" add -A &&
    gitc -C "$seed/s" commit -qm x
  git -C "$seed/s" push -q "$HOME/platform.git" feat/x feat/x:refs/pull/7/head
  rm -rf "$seed"
  git clone -q "$HOME/platform.git" "$HOME/work/platform"
}
gitc() { git -c user.name=t -c user.email=t@example.com -c commit.gpgsign=false "$@"; }
sha_of() { git -C "$HOME/platform.git" rev-parse "$1"; }

# pr <head repo> [state] [issues JSON]: a pull request as GraphQL returns it
DEFAULT_ISSUES='[{"number":12,"repository":{"nameWithOwner":"acme/platform"}}]'
pr() {
  local head; head="$(sha_of feat/x 2>/dev/null)" || head=abc
  export STUB_PR; STUB_PR="$(jq -nc --arg r "$1" --arg s "${2:-OPEN}" --arg h "$head" --argjson i "${3:-$DEFAULT_ISSUES}" \
    '{state: $s, headRefOid: $h, headRepository: (if $r == "" then null else {nameWithOwner: $r} end), closingIssuesReferences: {nodes: $i}}')"
}

# lock <session> <ref>: a lock as test-lock.sh would leave it
lock() {
  mkdir -p "$QA_LOCKS/test"
  printf '# owner\n\n- session: %s\n- ref: %s\n- since: 2026-10-13T08:00:00Z\n' "$1" "$2" > "$QA_LOCKS/test/owner"
}

run() { OUT="$("$@" 2>"$HOME/err")"; RC=$?; ERR="$(cat "$HOME/err")"; }
calls() { cat "$HOME/$1.calls" 2>/dev/null; }

fail() { echo "  ✗ $CASE: $*" >&2; FAILED=1; }
is() { [ "$1" = "$2" ] || fail "$3: expected '$2', got '$1'"; }
has() { case "$1" in *"$2"*) ;; *) fail "$3: no '$2' in: $(printf '%s' "$1" | head -c 400)" ;; esac; }
lacks() { case "$1" in *"$2"*) fail "$3: unexpected '$2'" ;; esac; }
done_() { rm -rf "$HOME"; }
