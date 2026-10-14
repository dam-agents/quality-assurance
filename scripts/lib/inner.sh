#!/usr/bin/env bash
# inner.sh: how the scripts reach the platform under test. Sourced, never run.
#
# The addresses and the dev user are the platform's local defaults (its
# helm/values-local.yaml), not secrets. Every call goes straight to this host:
# `*.localhost` must never leave through a proxy or the guest's DNS.

# The image's MISE_DATA_DIR is the runner's tools folder, a share every machine
# of the runner mounts from its host. mise unpacks a large archive there only to
# fail its check that the target folder stays the same (Java, zig). The
# platform's tools go under HOME instead, a plain disk that also keeps them
# across a restart.
export MISE_DATA_DIR="${QA_MISE_DATA_DIR:-$HOME/.local/share/mise}"

# low ...: a command at the lowest CPU priority, and the idle I/O class where
# the kernel has one. The platform's install keeps every vCPU busy, and the
# runner restarts a guest whose agent runtime misses its health probe (2 s)
# for 45 s. Everything the install starts, the cluster too, inherits it, so
# the agent runtime always gets the CPU first.
low() {
  if command -v ionice >/dev/null 2>&1; then nice -n 19 ionice -c 3 "$@"; else nice -n 19 "$@"; fi
}

UI_URL="${QA_UI_URL:-http://localhost:4444}"
KC_HOST="keycloak.localhost"
KC_PORT="${UI_URL##*:}"
DEV_USER="${QA_DEV_USER:-dev}"
DEV_PASSWORD="${QA_DEV_PASSWORD:-dev}"

local_curl() {
  curl --noproxy '*' --resolve "$KC_HOST:$KC_PORT:127.0.0.1" "$@"
}

k3s_up() { pgrep -x k3s-server >/dev/null 2>&1; }
ui_up() { local_curl -fsS -o /dev/null --max-time 10 "$UI_URL/" 2>/dev/null; }

# inner_token: an access token for the dev user, by the password grant the
# platform's own end-to-end tests use. It lives minutes: fetch one per script.
inner_token() {
  local_curl -fsS --max-time 20 "http://$KC_HOST:$KC_PORT/realms/platform/protocol/openid-connect/token" \
    -d grant_type=password -d client_id=platform-ui \
    --data-urlencode "username=$DEV_USER" --data-urlencode "password=$DEV_PASSWORD" |
    jq -er .access_token
}

# dam ...: the dam CLI built from the checkout, logged in as the dev user.
# Needs DAM_TOKEN (inner_token) in the environment.
dam() {
  NO_PROXY="localhost,127.0.0.1,.localhost${NO_PROXY:+,$NO_PROXY}" no_proxy="localhost,127.0.0.1,.localhost" \
    DAM_SERVER="$UI_URL" node "$(checkout_dir)/packages/cli/dist/js/bin.js" "$@"
}

# The prefix of everything a test creates on the platform under test, and the
# name of the one thing the setup creates there, which no cleanup touches.
QA_PREFIX="qa-"
MODEL_CONNECTION="outer-model"
