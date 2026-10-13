# The definition, its version, and `work/`

Read this when you are asked for your version or an update, or for a change to
this definition itself.

## Two places, never mixed

| Path | Kind | Holds |
| --- | --- | --- |
| `$HOME` | the definition, a git checkout (`origin`) | `kit.yaml`, `CLAUDE.md`, `AGENTS.md`, `ONBOARDING.md`, `README.md`, `VERSION`, `CHANGELOG.md`, `.gitignore`, `docs/`, `scripts/`, `.github/`, `.agents/skills/qa-test/` |
| `$HOME/work` | runtime state, a plain directory | `CONFIG.md`, `AGENTS.md`, `VERSION`, `ENV.md`, `TEST.log`, `logs/`, `locks/`, and the checkout of `repo` |

The `.gitignore` at `$HOME` is an allowlist, so `work/` and the home's secrets
(`.ssh`, `.claude`, `.config`) are invisible to the definition. **Never
`git clean` in `$HOME`**, and never `git add` outside the paths in the table.

Nothing in `work/` is backed up. A lost `CONFIG.md` costs one onboarding:
delete `$HOME/.quality-assurance-onboarded` and follow `ONBOARDING.md`.

## Definition version & upgrade

`VERSION` is the definition's version; `work/VERSION` is the one this instance
last adopted.

**Check:**

```sh
branch="$(git -C "$HOME" ls-remote --symref origin HEAD | sed -n 's#^ref: refs/heads/\([^[:space:]]*\).*#\1#p')"
git -C "$HOME" fetch -q origin "$branch"
git -C "$HOME" show FETCH_HEAD:VERSION | head -1   # latest
head -1 "$HOME/VERSION"                            # checked out
head -1 "$HOME/work/VERSION"                       # adopted
```

Checked out behind latest: tell the person both versions, and update only
when they ask. Adopted behind checked out: migrate now.

**Update** a clean checkout by fast-forward:

```sh
git -C "$HOME" status --porcelain            # must be empty, otherwise stop and ask
git -C "$HOME" merge --ff-only FETCH_HEAD
```

**Migrate:** apply the `CHANGELOG.md` **Upgrade** blocks of every version
crossed, oldest first; run `bash "$HOME/scripts/verify-onboarding.sh" --live`
and apply every fix; only then write the new version to `work/VERSION`.

## Evolving the definition

**First read [self-modification.md](self-modification.md).** You may not
write to GitHub (`CLAUDE.md` → **Hard invariants**), so a change you are
asked for goes to the person as a patch, never as a push. Work in a clone of
its own, never in `$HOME`:

```sh
d="$(mktemp -d)"; git clone "$(git -C "$HOME" remote get-url origin)" "$d"
# edit in "$d", run self-modification.md §5's checks there
git -C "$d" diff > /tmp/definition.patch
```

Show the patch and hand it to the person. They open the pull request; `$HOME`
takes it at the next **Update**, once merged.
