---
name: qa-test
description: >
  Test one request on the platform under test, the way a person would use it:
  take the test lock, get the platform to the ref, plan the steps, click
  through them in the shared browser, report a verdict per step, clean up.
  Use for every "test PR #<n>" and "test <what> on <ref>" request in the
  direct session (CLAUDE.md → Requests).
---

# Test a request

`CLAUDE.md` sets the rules this works within: the **Trust boundary**, the
blind rule in **Requests**, and the **Hard invariants**. `$S` below is
`$HOME/scripts`.

## 1. What to test, and on what

- **`test PR #<n>`:** `bash $S/pr-issues.sh <n>`. Exit `1`: refused (a fork,
  or not open); say why and stop. Exit `3`: it closes no issue; unless the
  person named one, say so and stop. Otherwise the spec is every issue it
  prints, or the one the person named: `gh issue view <n> --repo <owner/name>
  --comments` for each. The ref is `PR #<n>`.
- **`test <what> on <ref>`:** the spec is the request's text. The ref is the
  branch, or `PR #<n>`; none named, the default branch of `repo`. Not blind:
  you may read anything, but you still test through the UI.

## 2. Lock, and the environment

```sh
bash $S/test-lock.sh take "<ref>"
```

Exit `1`: reply with the line it printed ("busy testing …") and stop. Taken:

```sh
bash $S/cleanup.sh                            # what a failed test before you kept
bash $S/ensure-env.sh <branch> | --pr <n>     # background task: minutes to half an hour
```

While it runs, plan (step 3). When it ends:

- `ready: <ref> at <sha>`: go on.
- Exit `2`: refused (a fork, a branch that does not exist). Release with
  `blocked` and say why.
- Exit `1`: it failed. Read [`docs/environment.md`](../../../docs/environment.md),
  try what it says once, then stop: the verdict is **Blocked**, with what
  failed and the end of the log.

## 3. Plan

Before you click, write the steps: what a person does, and what they should
see. Cover the main path first, then what the spec names: each acceptance
criterion, each case its comments add. Keep it to what the spec asks; this is
not a regression run.

Mark a step **untestable** up front when it needs what this platform does not
have: a real credential other than the model (GitHub, Slack, a cloud), an
outside service, a second person, more time than the turn. It is still a step,
and the report counts it.

## 4. Test

- The platform is at `http://localhost:4444`; sign in as `dev`, password
  `dev` (the platform's local default user, not a secret).
- Use the browser as the `agent-browser` skill says, in its shared profile, so
  the person can watch in the Browser Panel. Give them the link once, when you
  open the platform: `[Watch the test](platform://browser?url=<encoded url>)`.
- Name everything you create `qa-<YYYYMMDDHHMM>-<what>`, in UTC.
- An agent you create on the platform under test uses the `outer-model`
  connection: that is the real model.
- For each step: do it, look at what the page shows, and write down what you
  saw. A failure gets: what you did, what you expected, what you saw, and a
  screenshot path when it helps.
- Something breaks that the spec does not cover: note it as an extra finding,
  do not chase it.

## 5. Report and release

Clean up unless it failed, then release with the verdict:

```sh
bash $S/cleanup.sh       # not after a Failed test: what it made stays for a person to look at
bash $S/test-lock.sh release passed|failed|blocked
```

Then reply in the chat, in this shape:

```
**<Passed|Failed|Blocked>** · <ref> at <short sha> · <N> of <M> steps tested
Spec: <issue links, or "the request">

| # | Step | Result | What I saw |
| 1 | … | passed / failed / untestable | … |

Failed steps: what you did · expected · saw
Not tested: each untestable step, and why
Other findings: anything broken outside the spec
Left on the platform: what a Failed test kept, or "nothing"
```

- **Passed:** every tested step passed. Steps left untested still show in
  "N of M".
- **Failed:** at least one tested step failed.
- **Blocked:** no step could be tested: the environment did not come up, the
  spec could not be read, or the platform at that ref cannot reach the model.
- Plain words a person can act on. No code reading, no guessing why it fails
  in a blind test: say what a user sees.
