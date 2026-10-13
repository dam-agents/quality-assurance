# The platform under test

Read this when `ensure-env.sh` fails, or the platform under test stops
answering in the middle of a test.

## What is where

| Path | Holds |
| --- | --- |
| `work/<name>` | the checkout of `repo`, detached at the ref under test |
| `work/ENV.md` | what is installed: `ref`, `sha`, `state` (`installing`, `ready`, `failed`), since when its data is (`data_since`) |
| `work/logs/` | the output of the last install, uninstall, restart and CLI build |
| `~/.local/share/k3s` | the cluster and its image cache, which survive a restart |

The install, the uninstall and the cluster are the platform's own: its mise
tasks, run from the checkout. How they work and how to recover them is the
platform's to document. Its `cluster-ops` skill covers the usual failures.
Read it **from the default branch**, never from the checkout: in a blind test
the checkout is the code under test.

```sh
git -C "$HOME/work/<name>" show origin/HEAD:.agents/skills/cluster-ops/SKILL.md
```

## When it fails

Try one fix, then report **Blocked** with what failed and the end of the log.
Do not hand-patch the cluster: a result from a state you patched by hand says
nothing.

- **The install fails at a step that has nothing to do with the ref**
  (a download, a full disk, an image import): the log names it. `mise run
  cluster:prune` in the checkout frees disk; then run `ensure-env.sh` again.
- **The install works, the model does not answer** on the platform under
  test: an older ref may predate how the install trusts this sandbox's
  gateway. Report it as Blocked and name the ref.
- **`inner-setup.sh` fails to log in**: the platform at this ref may use
  other local defaults. Say so; do not guess passwords.
- **Nothing helps**: `mise run cluster:uninstall` in the checkout, and remove
  `work/ENV.md`. The next `ensure-env.sh` installs from scratch. Say that you
  did it.

## Data

A new ref starts with empty data: the uninstall removes the platform's
database and agents, and the cluster and images stay. The same ref keeps its
data across new commits and restarts. Asked to reset it on the same ref, do
what **Nothing helps** says, under the lock.
