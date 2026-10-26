---
name: codespace-sandbox
description: Run approved tests, builds, or experiments in a newly created disposable GitHub Codespace, retrieve results, and verify deletion. Use for on-demand Linux isolation or costly local workloads; prefer local execution for lightweight tests and GitHub Actions for repeatable CI.
compatibility: Codex, Claude Code, and Gemini CLI with POSIX sh, GitHub CLI, jq, OpenSSH (ssh and ssh-keygen), and standard Unix utilities. GitHub Codespaces permissions and independently verified remaining included allowance are required.
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

## Establish allowance and run

Read [GitHub contracts](references/github-contracts.md) for API details, permission
requirements, and limits of billing evidence. Verify the authenticated account,
the repository's billable owner, and that owner's **remaining** included compute
and storage allowance for the current billing period. Missing billing access or
unverifiable allowance is a blocker; never infer unlimited or free capacity.

The helper requires explicit allowance values established independently from
current account billing evidence. These are assertions, not billing measurements.
Do not invent numbers or substitute the plan's full monthly allotment for the
remaining allowance. Account for other concurrent workloads and the billing
period boundary. The helper checks conservative estimated bounds against the
assertions and independently checks the API's billable owner before creation.
It does not reserve quota against concurrent consumers.

Run the package-relative script with the exact user-approved command. Quote the
command as one argument; do not expand untrusted values into its shell syntax.
For example, after verifying at least the example allowance remains:

```sh
sh <skill-dir>/scripts/run.sh \
  --repo alexcatdad/skills --ref main \
  --command 'sh tests/check.sh' \
  --billing-owner alexcatdad \
  --included-core-hours 1 --included-storage-gb-hours 100 \
  --output /approved/private/output/codespace-run
```

The example allowance numbers are illustrative, not a statement about any
account. Use an approved temporary or private output directory. The script
resolves the ref to an immutable commit before creation; uncommitted local changes
are not tested. No manual VM setup or local dependency installation is needed.

Optional flags select `--machine NAME`, `--timeout SECONDS`,
`--provision-timeout SECONDS`, and `--artifact RELATIVE_PATH`. Machine names come
from the repository/ref machine API; the default is the smallest available
machine, preferably two cores. Request a larger machine only with a workload
justification or explicit user instruction. Artifact paths refer to repository
files/directories; retrieve only approved nonconfidential outputs. Never upload
logs or artifacts publicly.

Defaults are 300 seconds for remote execution and 180 seconds for provisioning.
`--output` must name a new absolute directory. The helper writes `result.json`,
`stdout.log`, `stderr.log`, and relevant lifecycle/transfer diagnostics there.
The result separates `command_exit_code` (null if unavailable) from the overall
`exit_code`, records `artifact_status`, and lists `remaining_resources`. Preflight
failures include the GitHub CLI's first diagnostic line in `error`, with full
stderr saved as `preflight-*.stderr`. When the billing usage endpoint is
accessible, `reported_usage` summarizes the current month's Codespaces items as
GitHub reports them (null otherwise); use it to re-check the asserted allowance,
never as proof of remaining capacity. Process
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
