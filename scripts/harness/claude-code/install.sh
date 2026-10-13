#!/usr/bin/env bash
# Wires this definition into Claude Code: links ~/.claude/skills to
# ~/.agents/skills, where the bundled qa-test skill lives beside the
# platform's own (agent-browser among them). Left alone when the platform
# already links it. Idempotent. On another harness it says so and exits 0.
set -u
if [ "${CLAUDECODE:-}" != 1 ] && [ -z "${FORCE_INSTALL:-}" ]; then
  echo "not the Claude Code harness: nothing installed"
  exit 0
fi
RC=0
mkdir -p "$HOME/.claude"
if [ -e "$HOME/.claude/skills" ] || [ -L "$HOME/.claude/skills" ]; then
  echo "skills: ~/.claude/skills already there"
else
  ln -s ../.agents/skills "$HOME/.claude/skills" && echo "skills: linked ~/.claude/skills -> ~/.agents/skills"
fi
[ -f "$HOME/.claude/skills/qa-test/SKILL.md" ] ||
  { echo "skills: qa-test does not resolve through ~/.claude/skills"; RC=1; }
exit "$RC"
