# Changelog

**Migration instructions, not a change log.** Per version, the idempotent
**Upgrade** steps a deployed instance applies when it crosses that version.
Most versions need nothing. What changed and why lives in the pull requests.

## 0.1.5 (2026-10-14)

The scripts run the platform's install, and everything it starts, at the
lowest CPU priority. The install kept every vCPU busy, the agent runtime
missed its health probe, and the runner restarted the guest within a minute.

**Upgrade:** none.

## 0.1.4 (2026-10-14)

The kit asks for 8 CPUs and 8Gi of memory instead of 12 and 16Gi: one
platform install needs no more, and a VM that large pushed a laptop host into
swap until the runner restarted it.

**Upgrade:** `kit.yaml` reaches new agents only. An agent created before keeps
its size until the operator changes it or creates the agent again
(operator-only).

## 0.1.3 (2026-10-13)

The scripts install the platform's tools under `~/.local/share/mise` instead
of the image's tools folder, a share from the runner's host where mise could
not unpack Java or zig. The first install downloads every tool once more.

**Upgrade:** none.

## 0.1.2 (2026-10-13)

`ensure-env.sh` installs the checkout's tools with one `mise install` before
the platform's install, whose parallel builds otherwise raced to unpack the
same tool.

**Upgrade:** none.

## 0.1.1 (2026-10-13)

The Browser Panel needs no feature turned on: onboarding and the README no
longer ask for one.

**Upgrade:** none.

## 0.1.0 (2026-10-13)

First version. Started from `dam-agents/software-developer` 5.2.1, with the
code-writing parts removed: no schedules, no slots, no pull requests. Tests
run only when asked in the direct session.

**Upgrade:** none. Create a new agent from the kit.
