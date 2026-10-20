#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"
for skill in environment-preflight html-session-progress codespace-sandbox; do
  package=skills/$skill
  [ -f "$package/SKILL.md" ]
  [ "$(head -1 "$package/SKILL.md")" = --- ]
  [ "$(sed -n '2p' "$package/SKILL.md")" = "name: $skill" ]
  awk '/^description: / { if(length($0)<=13 || length($0)>1037) exit 1; found=1 } END { if(!found) exit 1 }' "$package/SKILL.md"
done
[ -f skills/html-session-progress/assets/page.html ]
for script in skills/environment-preflight/scripts/preflight.sh skills/html-session-progress/scripts/render.sh skills/html-session-progress/scripts/serve.sh skills/codespace-sandbox/scripts/run.sh; do
  [ -x "$script" ]
  sh -n "$script"
done
for script in tests/check.sh tests/skills/smoke.sh tests/skills/serve-smoke.sh tests/skills/codespace-smoke.sh; do sh -n "$script"; done
sh tests/skills/smoke.sh
sh tests/skills/serve-smoke.sh
sh tests/skills/codespace-smoke.sh
if command -v zsh >/dev/null 2>&1; then
  TEST_SHELL=$(command -v zsh) sh tests/skills/smoke.sh
  TEST_SHELL=$(command -v zsh) sh tests/skills/serve-smoke.sh
fi
echo 'PASS: skill structure, metadata, executable modes, shell syntax and behavior.'
