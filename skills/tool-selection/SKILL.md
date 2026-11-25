---
name: tool-selection
license: MIT
description: Recommend a tool, library, language, framework, or stack for a defined task when the choice is open. Skip when the goal is unclear or the project already has a suitable choice.
---

NEVER pick from memory or habit; NEVER default to Python, Node or the most popular option
NEVER install or scaffold a candidate before the owner answers
IF the project already uses a tool for this: use it, stop here
IF the goal is unclear: use clarify before comparing tools
DO list constraints first: platform, runtimes already installed, performance, maintenance, licence
IF a constraint is unknown and changes the answer: ask one question
DO research 2-3 candidates with the session browser/search: primary docs, source repo, release dates, open issues; ignore ranked or sponsored lists
IF a built-in or existing CLI does the job: it is a candidate
FOR EACH candidate: fit to constraints, maturity, last release, install cost, one real drawback

ON END:
DO one table (candidate × criteria), one recommendation with reasons, sources as links; then wait
