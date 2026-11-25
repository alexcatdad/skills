---
name: agent-instructions
license: MIT
description: Write, edit, review or shrink agent-facing instructions (AGENTS.md, CLAUDE.md, SKILL.md, hook rules). Use before changing any of them.
---

ALWAYS one statement per line, starting with a keyword: NEVER, ALWAYS, IF … ELSE, WHILE, FOR EACH, ON END, DO
ALWAYS fragments: trigger, colon, action; slashes for alternatives; no filler words
ALWAYS write for an agent reader; the owner edits these files only through agents
NEVER prose, bullets, emphasis, headings as structure, or a softer DON'T tier
NEVER a line that needs another line to be read correctly
DO include paths, architecture or exact commands when needed to run or verify the task

FOR EACH rule: one home
IF true for every task and not discoverable from the repo: global AGENTS.md
IF true for one repo: that repo's AGENTS.md
IF a procedure needed only sometimes: a skill whose description says when
IF it must always or never happen and a script can check it: a hook, plus at most one line of prose
IF guidance is vague or duplicated: drop it
IF guidance is discoverable or already followed: keep it only when needed to run or verify the task or explicitly requested

IF the owner states a rule: keep their words and scope; flag anything you add as an assumption, ask
IF a new rule contradicts an existing one: stop, quote both, ask which wins
IF adding a rule: merge into an existing line first
IF emphasis keeps being added to a line: move it to a hook
FOR EACH rewrite: count tokens before and after with an available counter; otherwise count words and say so; never grow without new rules

ON END:
DO report lines and token or word counts before/after; rules added, merged, dropped; contradictions found
