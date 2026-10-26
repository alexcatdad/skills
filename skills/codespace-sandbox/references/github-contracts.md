# GitHub contracts and cost boundaries

Use authenticated `gh` against github.com. The CLI and API are separate interfaces:
CLI JSON fields are camelCase; REST JSON fields are snake_case. Validate response
types and required fields before using them. An unavailable endpoint is not proof
of available allowance; the $0 budget below is the cost boundary.

## Read-only preparation

- `gh api user` identifies the authenticated account (`login`, `id`, `type`).
- `GET repos/{owner}/{repo}/commits/{ref}` resolves a published branch or commit to
  its full `sha`. Resolve before creation, then verify the remote checkout's exact
  `HEAD` before executing the requested command. Unpublished local changes are not
  included. Never push just to make sandbox testing work.
- `GET repos/{owner}/{repo}/codespaces/new?ref={sha}` returns defaults and
  `billable_owner`, an object containing `login`, `id`, and `type`. Establish the
  expected payer before creation; do not infer it from the repository owner.
- `GET repos/{owner}/{repo}/codespaces/machines?ref={sha}` returns `machines`, an
  array containing `name`, `cpus`, `memory_in_bytes`, `storage_in_bytes`, and
  `operating_system`. Discover and rank these values; machine names are opaque.
  A repository's devcontainer can restrict the available machines.

Sources: [Codespaces REST API](https://docs.github.com/en/rest/codespaces/codespaces),
[machine metadata](https://docs.github.com/en/rest/codespaces/machines),
[commit lookup](https://docs.github.com/en/rest/commits/commits#get-a-commit).

## Create, connect, retrieve, and delete

`gh codespace create` supports `--repo`, `--branch`, `--machine`,
`--display-name`, `--idle-timeout 5m`, `--retention-period 1h`, and
`--default-permissions`. The last flag declines prompts for extra devcontainer
permissions; it does not grant all requested permissions. Avoid `--web`, which
cannot be combined with the display-name, idle-timeout, or retention flags.

The REST create endpoint `POST repos/{owner}/{repo}/codespaces` accepts `ref`,
`machine`, `display_name`, `idle_timeout_minutes`, `retention_period_minutes`, and
`multi_repo_permissions_opt_out`. It returns the exact resource `name`, `owner`,
`billable_owner`, `repository`, `machine`, and `prebuild`. A 202 response means
creation partially failed and GitHub is retrying in the background. A failed or
timed-out client request can therefore leave a resource. Never blindly retry
creation. Retain a unique request display name before sending the request and
reconcile only an exact match with the authenticated owner and target repository.
Ambiguous matches require a clear report, never broad deletion.

`gh codespace ssh --codespace NAME -- sh -s` can receive a script over standard
input. Pass the approved command as script content, not interpolated SSH flags or
shell command fragments. SSH requires an SSH server in the devcontainer. The CLI
may create its connection key under `~/.ssh`; do not copy local private keys into
the codespace.

Do not assume the `gh codespace ssh` process status equals the remote test status.
The CLI wraps SSH subprocess failures, so preserve the command's exit status in
an explicit result file or a controlled result channel and retrieve it separately.
Treat a missing result as an execution/connection failure. See the official
[SSH implementation](https://github.com/cli/cli/blob/trunk/pkg/cmd/codespace/ssh.go)
and [CLI exit handling](https://github.com/cli/cli/blob/trunk/internal/ghcmd/cmd.go).

`gh codespace cp --codespace NAME remote:/absolute/path LOCAL_DIRECTORY` treats
remote names literally. Never use `--expand` with supplied artifact paths: that
flag permits remote shell expansion. Use `--recursive` for directories.

Delete only the tracked resource with `gh codespace delete --codespace NAME
--force`. REST deletion is asynchronous (202 Accepted), so verify absence with
`GET user/codespaces/{name}` after deletion. A transport failure or permission
error is not absence. Inspecting or stopping a tracked resource as a fallback
must preserve the same owner, repository, and request-identity checks. A stopped
resource still consumes storage until deletion.

The documented create interfaces have no per-request switch to disable existing
prebuild consumption. Do not configure or generate prebuilds. Inspect the created
resource's `prebuild` field and refuse execution, then clean up, if a prebuild was
used. The REST schema allows `null`; treat only `true` as prebuild use, and a
missing field as unknown. Do not claim the API disables prebuilds before creation.

Sources: [create CLI](https://cli.github.com/manual/gh_codespace_create),
[SSH CLI](https://cli.github.com/manual/gh_codespace_ssh),
[copy CLI](https://cli.github.com/manual/gh_codespace_cp),
[delete CLI](https://cli.github.com/manual/gh_codespace_delete),
[REST lifecycle](https://docs.github.com/en/rest/codespaces/codespaces),
[prebuild behavior](https://docs.github.com/en/codespaces/prebuilding-your-codespaces/about-github-codespaces-prebuilds).

## Billing is not an atomic quota check

Personal accounts can have monthly included compute and storage. Organization
accounts do not receive this personal allowance. Compute consumes core-hours
while active; storage accumulates while a codespace exists, including when it is
stopped. Retention and idle timeout are fallbacks, not cleanup verification.

`GET users/{username}/settings/billing/usage` supports `year` and `month` and
returns `usageItems` with product, SKU, quantity, unit type, and monetary amounts.
It is available only on the enhanced billing platform and needs billing access.
The documented schema does not provide an atomic remaining-included-allowance
reservation or guarantee real-time consumption. An empty result or zero net
amount does not establish fresh compute and storage headroom. Do not derive free
capacity merely from a plan name or the absence of a payment method field.

Because remaining headroom cannot be established, the cost boundary is the billing
owner's Codespaces budget: $0 and set to stop usage at the limit, so usage past
the included allowance is blocked rather than billed. Require the user's
confirmation of that setting and the correct payer before provisioning; never
infer it. Usage data and estimates (provisioning, execution, and storage until
verified deletion) are informational; label estimates separately from GitHub
usage data. Never change payment settings, budgets, or spending limits.

Classic/OAuth tokens require `codespace` for Codespaces lifecycle APIs. Fine-grained
tokens require the relevant repository Codespaces permissions; machine discovery
uses Codespaces metadata read access. Billing user endpoints document Plan read
permission for fine-grained tokens. Do not automatically broaden token scopes.
An HTTP 404 can mean inaccessible metadata, not a nonexistent repository.

Sources: [Codespaces billing](https://docs.github.com/en/billing/concepts/product-billing/github-codespaces),
[included usage](https://docs.github.com/en/codespaces/troubleshooting/troubleshooting-included-usage),
[billing API](https://docs.github.com/en/rest/billing/usage),
[billing ownership](https://docs.github.com/en/codespaces/managing-codespaces-for-your-organization/choosing-who-owns-and-pays-for-codespaces-in-your-organization).
