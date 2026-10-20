---
name: environment-preflight
description: Run a lightweight task-specific preflight before substantial environment-dependent work, including when AGENTS.md requires preflight, and when diagnosing a host or capability mismatch. Check the execution host and intended target separately; skip text-only answers, trivial operations and unchanged prerequisites already checked in this session.
compatibility: POSIX sh or Zsh with native Unix utilities on macOS, Linux or WSL. No runtime package installation. Additional tools and versions are checked only when required by the task.
---

# Environment preflight

Resolve prerequisites before substantial work. Aim for seconds. Cache results in session context per execution host, workspace, target and required capabilities; recheck only changed facts or a relevant failure.

1. Discover the interpreter with `command -v sh`; otherwise `command -v zsh`. Use `sh` for bundled helpers when available, or `zsh -f` if only Zsh is available. Direct executable launch uses `/bin/sh`; use the explicit interpreter when that path is absent. If neither exists, use client-native checks and report the limitation. Do not install a shell. `$SHELL` alone does not identify the current interpreter or available commands.
2. Read applicable workspace instructions and immediate task manifests/version pins. Identify operations and target. Run `sh <skill-dir>/scripts/preflight.sh --workspace "$PWD" --target current --tool REQUIRED_TOOL`; replace the placeholder with actual task tools, repeat `--tool` or omit it. Use `--target remote` or `unknown` honestly. The helper reports actual host OS/architecture/name, available shells, execution-shell context, SSH/container/VM signals and directory access. Missing VM signals mean unknown. Keep host identity private.
3. Confirm client sandbox and transport boundaries. Check remote prerequisites on the confirmed target through already authorized transport. Local availability, versions and credentials cannot prove VM or remote readiness; keep evidence separate per machine.
4. Inspect relevant skills/connectors already exposed by the client. Only if needed, inspect matching descriptions in documented project/client `.agents/skills`, `.claude/skills`, `.gemini/skills` roots or user equivalents. Avoid home scans or loading unrelated Skills.
5. Verify essential tools against project pins. `--tool` checks availability only; use narrowly scoped version/capability commands when needed. Use existing tools. Preflight does not install, log in, elevate or provision; proceed with actions already authorized by the task without redundant approval.
6. `--credential-env REQUIRED_VARIABLE` uses native `printenv` for presence only, without printing values. If unavailable, report the capability as unverified. A readable credential file is not proof of validity. Make one bounded read-only provider check only when needed; suppress raw output/errors. Never dump environment/configuration, tokens or credentials. Read access does not prove write access.
7. Directory write flags are advisory. When required, pass `--writable AUTHORIZED_OUTPUT_DIRECTORY` for a reversible create/remove probe only there. Inspect sandbox grants separately. Do not mutate remote resources merely to probe access.
8. Return ready, ready with caveats, or blocked, with current versus target identity and the smallest corrective action. Helper exit 1 means missing prerequisites or unsupported host; exit 2 means invalid arguments. Stop dependent work on genuine blockers and alert promptly; continue independent work. Missing optional tools or uncertain VM detection alone are not blockers.

Bound network/provider probes to a few seconds through client command timeouts or an existing native timeout utility. Time-box troubleshooting; no unchanged retries. The helper makes no network calls, runs no requested executable and evaluates no argument as code. No persistent cache, daemon or compatibility framework.
