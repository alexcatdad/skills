#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"
for skill in artifact codespace-sandbox agent-instructions tool-selection clarify; do
  package=skills/$skill
  [ -f "$package/SKILL.md" ]
  [ "$(head -1 "$package/SKILL.md")" = --- ]
  [ "$(sed -n '2p' "$package/SKILL.md")" = "name: $skill" ]
  awk '/^description: / { if(length($0)<=13 || length($0)>1037) exit 1; found=1 } END { if(!found) exit 1 }' "$package/SKILL.md"
done
[ -x skills/codespace-sandbox/scripts/run.sh ]
for script in skills/codespace-sandbox/scripts/run.sh tests/check.sh tests/skills/codespace-smoke.sh tests/skills/codespace-watchdog.sh; do sh -n "$script"; done
sh tests/skills/codespace-smoke.sh
sh tests/skills/codespace-watchdog.sh
echo 'PASS: skill structure, metadata, executable modes, shell syntax and behavior.'
