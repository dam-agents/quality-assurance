# quality-assurance

A DAM [starter kit](https://github.com/dam-agents/dam/blob/main/docs/architecture/starter-kits.md):
an agent that tests the platform the way a person uses it. It installs its own
copy of the platform in its sandbox, at the branch or pull request you name,
clicks through the web UI with a real model, and answers with a verdict per
step.

Ask it in chat:

- **`test PR #123`**: it builds the pull request and tests it against the
  issues the pull request closes. The test is blind: it reads the issues, not
  the code or the pull request's description, so it tests what was asked for
  rather than what was built. Name an issue to test against another one.
- **`test <what> on <branch>`**: it tests what you describe, on that branch or
  `PR #<n>`. With no ref, on the default branch.

Or ask in the agent's Slack channel, when one is bound and onboarding
recorded it: the same two requests, from a person (bots are refused). The
agent answers in the thread when the test starts and again with the report,
with a screenshot of the first failed step.

One test runs at a time. A second request while one runs is answered "busy
testing …" at once. The answer is **Passed**, **Failed** or **Blocked**, with
"N of M steps tested": a step it could not test is never counted as passed.

## What is here

- [`kit.yaml`](kit.yaml): what the platform creates. A `vm` agent that never
  hibernates, so the platform under test stays warm.
- [`CLAUDE.md`](CLAUDE.md): what the agent does, and what it never does.
- [`.agents/skills/qa-test/`](.agents/skills/qa-test/SKILL.md): the test
  procedure.
- [`ONBOARDING.md`](ONBOARDING.md): the first conversation, and the first
  install.
- [`scripts/`](scripts/): the lock (`test-lock.sh`), what a blind test may know
  about a pull request (`pr-issues.sh`), putting the platform at a ref
  (`ensure-env.sh`), its setup (`inner-setup.sh`) and cleanup (`cleanup.sh`).
  `bash scripts/tests/run.sh` tests them offline; CI runs it, and
  [`scripts/validate-definition.sh`](scripts/validate-definition.sh), on every
  pull request.

## Connections

**GitHub**, required. The agent only reads: it clones the repository and reads
pull requests and issues. Give it a read-only connection: a fine-grained token
or GitHub App with read on contents, issues and pull requests, on the
platform's repository alone.

**The model.** The platform under test needs a real model, and its key must
never enter the sandbox. It borrows the agent's own model connection: setup
gives the platform under test a connection that holds only that connection's
placeholder, `platform:conn:<id>`. The platform under test sends the
placeholder, and the agent's gateway swaps in the real key on the way out. The
cost of both shows on the one connection.

## Watching a test

The agent tests in the browser the Browser Panel shows, beside its chat. The
panel is there because the kit sets `requireConnectionAddress`; you turn
nothing on.

## What it keeps on the instance

All under `work/`, none of it tracked here:

| File | Written by | Holds |
| --- | --- | --- |
| `CONFIG.md` | onboarding | the repository, the model template, the Slack chat, bounds |
| `AGENTS.md`, `VERSION` | onboarding | a pointer to `CLAUDE.md`; the version this instance adopted |
| `<name>/` | `ensure-env.sh` | the checkout, at the ref under test |
| `ENV.md` | `ensure-env.sh` | what is installed: ref, commit, state |
| `logs/` | the scripts | the output of the last install and setup |
| `locks/test/` | `test-lock.sh` | who is testing what, since when |
| `TEST.log` | `test-lock.sh` | one line per test: verdict, ref, minutes |

There is no backup: a lost volume costs one onboarding.
