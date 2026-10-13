#!/usr/bin/env bash
# config.sh: the one reader of the `- key: value` files under work/:
# CONFIG.md, which onboarding writes, and ENV.md and the lock's owner file,
# which the scripts write. Sourced, never run.
#
# A key is read from its first `- <key>: <value>` bullet. A `*` bullet, spaces
# around the key and the key's case are tolerated. Everything after the key's
# colon is the value, so a URL survives. Backticks and trailing whitespace are
# stripped.

# WORKAROUND (environment, not this definition): the image puts mise's shim
# directory ahead of /usr/bin, holding shims for coreutils no active tool
# provides, so every `tr` or `sed` starts mise first, ~0.1 s a call. Shims go
# last: a real binary wins, and a tool only a shim has still runs.
case ":$PATH:" in
  *:*/mise/shims:*)
    _p=""; _s=""; _IFS="$IFS"; IFS=:
    for _d in $PATH; do case "$_d" in */mise/shims) _s="$_s:$_d" ;; *) _p="$_p:$_d" ;; esac; done
    IFS="$_IFS"; PATH="${_p#:}$_s"; export PATH; unset _p _s _d _IFS ;;
esac

# kv <file> <key>
kv() {
  [ -f "$1" ] || return 0
  grep -m1 -iE "^[-*]?[[:space:]]*$2[[:space:]]*:" "$1" 2>/dev/null |
    sed -E "s/^[-*]?[[:space:]]*[^:]+:[[:space:]]*//" |
    tr -d '`' |
    sed -E 's/[[:space:]]+$//'
}

# cfg <key>: a key of work/CONFIG.md
cfg() { kv "$HOME/work/CONFIG.md" "$1"; }

# write_kv <file> <title> key=value ...: <file> rewritten whole, tmp + mv
write_kv() {
  local file="$1" title="$2" pair tmp
  shift 2
  mkdir -p "$(dirname "$file")" || return 2
  tmp="$(mktemp "$(dirname "$file")/.$(basename "$file").XXXXXX")" || return 2
  {
    printf '# %s\n\nWritten by scripts/, never by hand.\n\n' "$title"
    for pair in "$@"; do
      [ -n "${pair#*=}" ] && printf -- '- %s: %s\n' "${pair%%=*}" "$(printf '%s' "${pair#*=}" | tr '\n' ' ')"
    done
  } > "$tmp" && mv -f "$tmp" "$file"
}

# repo_slug: `repo` without a host; repo_host: its host, github.com by default
repo_slug() { local r; r="$(cfg repo)"; case "$r" in */*/*) echo "${r#*/}" ;; *) echo "$r" ;; esac; }
repo_host() { local r; r="$(cfg repo)"; case "$r" in */*/*) echo "${r%%/*}" ;; *) echo github.com ;; esac; }

# checkout_dir: where `repo` is cloned
checkout_dir() { local s; s="$(repo_slug)"; echo "$HOME/work/${s##*/}"; }
