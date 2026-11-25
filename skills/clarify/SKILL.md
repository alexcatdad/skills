---
name: clarify
license: MIT
description: Turn an open or vague request into an agreed goal, scope and done-criteria before building. Use when a request leaves the goal, scope or expected result unclear, such as a new idea or "build a tool that does X". Skip when the expected result is stated, such as a bug ticket.
---

NEVER start building while goal, scope or done-criteria are open
NEVER assume an answer; NEVER ask what the request or the repo already answers
DO read the request and the relevant code first
FOR EACH open point, most blocking first: ask one question, wait for the answer
FOR EACH question: self-contained (file, quoted text, outcome per answer); 2-4 options; your recommendation and why
IF an answer opens a new point: queue it
IF the owner says "you decide": decide, record it as an assumption
WHILE questions remain: no implementation, no installs

ON END:
DO write the spec in at most 10 lines: goal, in scope, out of scope, done when, assumptions
DO ask for confirmation once; then execute without re-asking
