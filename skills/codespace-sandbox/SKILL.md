---
name: codespace-sandbox
description: Run approved tests, builds, or experiments in a newly created disposable GitHub Codespace, retrieve results, and verify deletion. Use for on-demand Linux isolation or costly local workloads; prefer local execution for lightweight tests and GitHub Actions for repeatable CI.
compatibility: Codex, Claude Code, and Gemini CLI with POSIX sh, GitHub CLI, jq, OpenSSH (ssh and ssh-keygen), and standard Unix utilities. GitHub Codespaces permissions and a user-confirmed $0 Codespaces budget that stops usage at the limit are required.
---

# Codespace sandbox

Use this skill only for requested remote execution. Installation alone does not
authorize provisioning. Each invocation creates one disposable environment;
never reuse an existing Codespace. These are development environments, not
security-hardened malware sandboxes.

## Choose and inspect

Use Codespaces for clean dependency installations, temporary PostgreSQL/Redis
integration tests, Linux checks from macOS, browser tests, disruptive builds, or
independent environments that would otherwise need local VMs. Prefer local tests
when inexpensive, GitHub Actions for normal CI and required PR checks, and the
homelab for persistent services or hardware-specific workloads.

Inspect the target repository, its devcontainer configuration and lifecycle
commands, intended command, resource needs, and selected ref before provisioning.
Creation executes repository-controlled setup. Avoid repositories configured to
inject sensitive Codespaces secrets, dotfiles, or application data. Do not copy
local environment files, credentials, SSH keys, or production data. Use synthetic
fixtures. Do not forward public ports, push commits, configure prebuilds, or change
billing/payment settings.

## Confirm budget and run

Read [GitHub contracts](references/github-contracts.md) for API details and
permission requirements. Charges are prevented by the billing owner's Codespaces
budget, not by this helper: it must be $0 and set to stop usage at the limit, so
usage beyond the included allowance is blocked instead of billed. No GitHub API
reports remaining included allowance; do not try to establish it per run.

Pass `--zero-budget-confirmed` only when the user has confirmed that setting for
the billing owner, in this session or in standing instructions. One confirmation
covers later runs until the user says the budget changed. Without it, ask once;
never infer it or change budgets yourself. The helper checks that the API's
billable owner matches `--billing-owner` before creation.

Run the package-relative script with the exact user-approved command. Quote the
command as one argument; do not expand untrusted values into its shell syntax.
For example:

```sh
sh <skill-dir>/scripts/run.sh \
  --repo alexcatdad/skills --ref main \
  --command 'sh tests/check.sh' \
  --billing-owner alexcatdad --zero-budget-confirmed \
  --output /approved/private/output/codespace-run
```

Use an approved temporary or private output directory. The script
resolves the ref to an immutable commit before creation; uncommitted local changes
are not tested. No manual VM setup or local dependency installation is needed.

Optional flags select `--machine NAME`, `--timeout SECONDS`,
`--provision-timeout SECONDS`, and `--artifact RELATIVE_PATH`. Machine names come
from the repository/ref machine API; the default is the smallest available
machine, preferably two cores. Request a larger machine only with a workload
justification or explicit user instruction. Artifact paths refer to repository
files/directories; retrieve only approved nonconfidential outputs. Never upload
logs or artifacts publicly.

Defaults are 300 seconds for remote execution and 600 seconds for provisioning,
which leaves room for custom devcontainer builds. The provisioning timeout counts
toward the estimated usage, so lower it for prebuilt images.
`--output` must name a new absolute directory. The helper writes `result.json`,
`stdout.log`, `stderr.log`, and relevant lifecycle/transfer diagnostics there.
The result separates `command_exit_code` (null if unavailable) from the overall
`exit_code`, records `artifact_status`, and lists `remaining_resources`. Preflight
failures include the GitHub CLI's first diagnostic line in `error`, with full
stderr saved as `preflight-*.stderr`. When the billing usage endpoint is
accessible, `reported_usage` summarizes the current month's Codespaces items as
GitHub reports them (null otherwise). It and `estimated_usage` are informational;
neither is proof of remaining capacity. Process
exit 124 indicates a command timeout, 130/143 interruption, and 1 an operational
failure; an available remote command failure is propagated unchanged.

## Report and cleanup

Inspect the helper's output and saved structured result. Report the repository,
tested commit, selected machine, exact command, command exit code, execution
duration, artifact outcome, cleanup status, remaining resources, and clearly
labeled estimated compute/storage consumption. Distinguish an infrastructure
failure from a failing test and from a failed artifact transfer.

Cleanup runs after command success, failure, timeout, or interruption, and verifies
absence of the exact created Codespace. If cleanup fails, preserve the reported
name and targeted `gh codespace delete --codespace NAME --force` recovery command;
do not claim deletion. Never delete by account, repository, wildcard, or guess.
If creation has an ambiguous outcome, use the unique run marker and verified
owner/repository to identify the run before any deletion. If identity cannot be
proved, stop and report it.

No shell trap can survive SIGKILL, machine loss, or every provider outage. The
five-minute idle timeout and short retention period are secondary safeguards,
not proof of deletion or a hard billing cap. Keep the local result until cleanup
is established; remove private logs when no longer useful.
