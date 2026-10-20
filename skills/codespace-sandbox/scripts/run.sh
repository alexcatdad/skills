#!/bin/sh
# Disposable Codespaces runner. No account-wide mutations.
set -u
umask 077
repo= ref= command= machine= output= artifact= billing_owner= core_budget= storage_budget=
timeout=300 provision_timeout=180
usage() {
  echo 'Usage: run.sh --repo OWNER/REPO --ref REF --command COMMAND --output DIR --billing-owner LOGIN --included-core-hours N --included-storage-gb-hours N [--machine NAME] [--timeout SECONDS] [--provision-timeout SECONDS] [--artifact RELATIVE_PATH]' >&2
  exit 2
}
while [ "$#" -gt 0 ]; do
  [ "$#" -ge 2 ] || usage
  case $1 in
    --repo) repo=$2;; --ref) ref=$2;; --command) command=$2;; --machine) machine=$2;;
    --output) output=$2;; --artifact) artifact=$2;; --billing-owner) billing_owner=$2;;
    --included-core-hours) core_budget=$2;; --included-storage-gb-hours) storage_budget=$2;;
    --timeout) timeout=$2;; --provision-timeout) provision_timeout=$2;; *) usage;;
  esac
  shift 2
done
[ -n "$repo" ] && [ -n "$ref" ] && [ -n "$command" ] && [ -n "$output" ] || usage
case $repo in *[!A-Za-z0-9_./-]*|/*|*/|*/../*|../*|*/..|*//*|*/*/*) usage;; */*) :;; *) usage;; esac
case $ref in -*|*[!A-Za-z0-9_./-]*) usage;; esac
case $output in /*) :;; *) echo 'Output directory must be an absolute path.' >&2; usage;; esac
case $timeout:$provision_timeout in *[!0-9:]*|:*|*:) usage;; esac
case $timeout in 0*) usage;; esac
case $provision_timeout in 0*) usage;; esac
[ "$timeout" -gt 0 ] && [ "$timeout" -le 86400 ] && [ "$provision_timeout" -gt 0 ] && [ "$provision_timeout" -le 3600 ] || usage
if [ -n "$artifact" ]; then
  case $artifact in /*|-*|..|../*|*/../*|*/..|*[!A-Za-z0-9_./-]*) usage;; esac
fi
for dependency in gh jq ssh ssh-keygen; do command -v "$dependency" >/dev/null 2>&1 || { echo "Missing dependency: $dependency" >&2; exit 2; }; done
[ ! -e "$output" ] || { echo 'Output directory must not already exist.' >&2; exit 2; }
mkdir -p "$output" || exit 2
output=$(cd "$output" && pwd) || exit 2
work=$(mktemp -d "${TMPDIR:-/tmp}/codespace-sandbox.XXXXXXXX") || exit 2
name= login= sha= cpus= disk= estimated_core= estimated_storage=
cleanup=not_created error= exit_code=1 duration=0 created=0 child= watchdog= ending=0 sequence=0
command_exit_code=null artifact_status=not_requested
marker="sandbox-$(date +%s)-${work##*.}"
# A portable watchdog bounds CLI calls without GNU timeout. Children are reaped.
cancel_watchdog() {
  [ -n "$watchdog" ] || return 0
  # A signal sent before the subshell installs its trap can be lost, including
  # USR1 on older shells. Wait for the trap and sleeper PID to be initialized.
  cancel_deadline=$(( $(date +%s) + 3 ))
  while [ ! -f "$watchdog_ready" ]; do
    if ! kill -0 "$watchdog" 2>/dev/null || [ "$(date +%s)" -ge "$cancel_deadline" ]; then
      kill -KILL "$watchdog" 2>/dev/null || :
      wait "$watchdog" 2>/dev/null || :
      return 1
    fi
    sleep 0
  done
  kill -USR1 "$watchdog" 2>/dev/null || :
  wait "$watchdog" 2>/dev/null || :
}
bounded() {
  limit=$1; shift
  sequence=$((sequence + 1))
  timed_out="$work/timed-out-$sequence"
  watchdog_ready="$work/watchdog-ready-$sequence"
  exec 3<&0
  "$@" <&3 3<&- & child=$!
  exec 3<&-
  (
    sleeper=
    trap '[ -z "$sleeper" ] || { kill "$sleeper" 2>/dev/null || :; wait "$sleeper" 2>/dev/null || :; }; exit 0' USR1 TERM INT HUP
    sleep "$limit" & sleeper=$!
    printf '%s\n' ready >"$watchdog_ready" || {
      kill -KILL "$child" 2>/dev/null || :
      kill "$sleeper" 2>/dev/null || :
      wait "$sleeper" 2>/dev/null || :
      exit 1
    }
    wait "$sleeper"; sleeper=
    : >"$timed_out"
    kill -TERM "$child" 2>/dev/null || :
    sleep 2 & sleeper=$!; wait "$sleeper"; sleeper=
    kill -KILL "$child" 2>/dev/null || :
  ) </dev/null >/dev/null 2>&1 & watchdog=$!
  wait "$child"; bounded_status=$?
  cancel_watchdog || bounded_status=1
  child= watchdog=
  if [ -f "$timed_out" ]; then return 124; fi
  return "$bounded_status"
}
api() { bounded 30 gh api "$@"; }
owned() {
  api "user/codespaces/$name" >"$work/identity.json" 2>"$work/identity.err" || return 1
  jq -e --arg name "$name" --arg login "$login" --arg repo "$repo" --arg marker "$marker" --arg billing "$billing_owner" '
    .name == $name and .owner.login == $login and ((.repository.full_name | ascii_downcase) == ($repo | ascii_downcase)) and .display_name == $marker and .billable_owner.login == $billing
  ' "$work/identity.json" >/dev/null
}
reconcile() {
  api --paginate user/codespaces >"$work/list.json" 2>"$work/list.err" || return 1
  jq -s --arg marker "$marker" --arg repo "$repo" --arg login "$login" '[.[].codespaces[] | select(.display_name == $marker and ((.repository.full_name | ascii_downcase) == ($repo | ascii_downcase)) and .owner.login == $login and (.name | test("^[A-Za-z0-9_-]+$")))] | if length == 1 then .[0].name else empty end' -r "$work/list.json" >"$work/found"
  name=$(cat "$work/found")
  [ -n "$name" ]
}
finish() {
  [ "$ending" -eq 0 ] || return
  ending=1
  trap '' HUP INT TERM
  if [ -n "$child" ]; then kill -KILL "$child" 2>/dev/null || :; wait "$child" 2>/dev/null || :; fi
  cancel_watchdog || :
  # A lost create response can still represent a successful allocation.
  if [ "$created" -eq 1 ] && [ -z "$name" ]; then reconcile || :; fi
  if [ -n "$name" ]; then
    cleanup=failed
    if owned; then
      bounded 30 gh codespace delete -c "$name" --force >"$output/cleanup.stdout" 2>"$output/cleanup.stderr" || :
      attempt=0
      while [ "$attempt" -lt 3 ]; do
        if api --paginate user/codespaces >"$work/after.json" 2>"$work/after.err" && jq -s -e --arg name "$name" '[.[].codespaces[] | select(.name == $name)] | length == 0' "$work/after.json" >/dev/null; then cleanup=deleted; break; fi
        attempt=$((attempt + 1))
        [ "$attempt" -ge 3 ] || sleep 1
      done
    else
      cleanup=ownership_unverified
    fi
  elif [ "$created" -eq 1 ]; then
    cleanup=creation_unresolved
  fi
  case $cleanup in failed|ownership_unverified|creation_unresolved)
    [ "$exit_code" -ne 0 ] || exit_code=1
    echo "Cleanup $cleanup; resource: ${name:-unknown}; unique display name: $marker" >&2
    if [ -n "$name" ]; then echo "After verifying ownership, recover with: gh codespace delete -c '$name' --force" >&2; fi;;
  esac
  jq -n --arg repository "$repo" --arg commit "$sha" --arg machine "$machine" \
    --arg command "$command" --arg codespace "$name" --arg cleanup "$cleanup" \
    --arg error "$error" --argjson exit_code "$exit_code" \
    --argjson command_exit_code "$command_exit_code" --arg artifact_status "$artifact_status" \
    --argjson duration_seconds "$duration" --arg core "$estimated_core" \
    --arg storage "$estimated_storage" --arg billing_owner "$billing_owner" --arg marker "$marker" '
    {repository:$repository, commit:$commit, machine:$machine, command:$command,
     codespace:$codespace, display_name:$marker, billing_owner:$billing_owner,
     exit_code:$exit_code, command_exit_code:$command_exit_code,
     artifact_status:$artifact_status, duration_seconds:$duration_seconds,
     cleanup:$cleanup, remaining_resources:(
       if $cleanup == "deleted" or $cleanup == "not_created" then []
       elif $codespace != "" then [$codespace] else ["unknown; inspect display_name"] end),
     error:$error, estimated_usage:{core_hours:(try ($core | tonumber) catch null),
       storage_gb_hours:(try ($storage | tonumber) catch null), actual_billing:false}}
  ' >"$output/result.json" || {
    echo 'Cannot write structured result.' >&2
    [ "$exit_code" -ne 0 ] || exit_code=1
  }
  rm -rf "$work"
  echo "Result: $output/result.json" >&2
}
fail() { exit_code=1; error=$1; echo "$error" >&2; exit 1; }
trap 'finish' EXIT
trap 'exit_code=130; error=interrupted; exit 130' INT
trap 'exit_code=143; error=terminated; exit 143' HUP TERM
bounded 30 gh auth status >"$output/preflight.stdout" 2>"$output/preflight.stderr" || fail 'GitHub authentication unavailable.'
api user >"$work/user.json" || fail 'Cannot establish authenticated user.'
login=$(jq -er .login "$work/user.json") || fail 'Missing authenticated identity.'
# Allowance is an explicit assertion of independently verified remaining included
# capacity. Usage reports alone do not establish fresh remaining entitlement.
[ -n "$billing_owner" ] && [ -n "$core_budget" ] && [ -n "$storage_budget" ] || fail 'Provide verified billing owner and remaining included compute/storage allowances; missing billing data is not free capacity.'
jq -en --arg c "$core_budget" --arg s "$storage_budget" '($c|tonumber) > 0 and ($s|tonumber) > 0' >/dev/null 2>&1 || fail 'Invalid included allowance.'
api "repos/$repo/commits/$ref" >"$work/commit.json" || fail 'Invalid repository or ref.'
sha=$(jq -er '.sha | select(test("^[0-9a-f]{40}$"))' "$work/commit.json") || fail 'Cannot resolve exact commit.'
api -X GET "repos/$repo/codespaces/new" -f "ref=$sha" >"$work/options.json" || fail 'Cannot establish Codespaces billing ownership.'
jq -e --arg owner "$billing_owner" '.billable_owner.login == $owner' "$work/options.json" >/dev/null || fail 'Billing ownership does not match the verified allowance.'
# This endpoint reports usage, not guaranteed remaining included capacity.
if api -X GET "users/$billing_owner/settings/billing/usage" -f "year=$(date +%Y)" -f "month=$(date +%m)" >"$work/billing.json" 2>"$work/billing.err"; then
  echo 'Billing usage endpoint accessible; included allowance still requires independent verification.' >"$output/billing-status.log"
else
  echo 'Billing usage endpoint unavailable; no free capacity inferred.' >"$output/billing-status.log"
fi
api -X GET "repos/$repo/codespaces/machines" -f "ref=$sha" >"$work/machines.json" || fail 'Cannot discover supported machines.'
if [ -z "$machine" ]; then
  machine=$(jq -er '.machines | map(select(.cpus > 0 and .storage_in_bytes > 0)) | sort_by(.cpus,.storage_in_bytes) | .[0].name // empty' "$work/machines.json") || fail 'No supported machine available.'
fi
jq -e --arg m "$machine" '.machines[] | select(.name == $m and .cpus > 0 and .storage_in_bytes > 0)' "$work/machines.json" >"$work/machine.json" || fail 'Unsupported machine type.'
cpus=$(jq -r .cpus "$work/machine.json")
disk=$(jq -r '.storage_in_bytes / 1000000000' "$work/machine.json")
estimated_core=$(jq -n --argjson c "$cpus" --argjson t "$timeout" --argjson p "$provision_timeout" '$c * ($t+$p+300)/3600')
estimated_storage=$(jq -n --argjson d "$disk" --argjson t "$timeout" --argjson p "$provision_timeout" '$d * ($t+$p+300+3600)/3600')
jq -en --argjson ec "$estimated_core" --argjson es "$estimated_storage" --arg c "$core_budget" --arg s "$storage_budget" '$ec <= ($c|tonumber) and $es <= ($s|tonumber)' >/dev/null || fail 'Estimated usage exceeds verified remaining included allowance.'
ssh-keygen -q -t ed25519 -N '' -f "$work/key" || fail 'Cannot create temporary SSH identity.'
jq -n --arg ref "$sha" --arg machine "$machine" --arg display "$marker" '{ref:$ref,machine:$machine,display_name:$display,idle_timeout_minutes:5,retention_period_minutes:60,multi_repo_permissions_opt_out:true}' >"$work/create.json"
created=1
provision_start=$(date +%s)
bounded "$provision_timeout" gh api -X POST "repos/$repo/codespaces" --input "$work/create.json" >"$work/create-result.json" 2>"$output/provision.stderr" || fail 'Codespace provisioning failed or timed out.'
name=$(jq -er '.name | select(test("^[A-Za-z0-9_-]+$"))' "$work/create-result.json") || fail 'Creation response lacks a safe Codespace identity.'
while :; do
  remaining=$((provision_timeout - $(date +%s) + provision_start))
  [ "$remaining" -gt 0 ] || fail 'Codespace readiness timed out.'
  [ "$remaining" -le 30 ] || remaining=30
  bounded "$remaining" gh api "user/codespaces/$name" >"$work/ready.json" 2>"$work/ready.err" || fail 'Cannot inspect Codespace readiness.'
  state=$(jq -r '.state // empty' "$work/ready.json")
  case $state in Available) break;; Failed|Deleted|Shutdown) fail 'Codespace failed to become available.';; esac
  sleep 1
done
owned || fail 'Created Codespace ownership is ambiguous; refusing remote execution.'
jq -e '.prebuild == false' "$work/identity.json" >/dev/null || fail 'Prebuild status is unknown or enabled; outside this runner policy.'
jq -e --arg machine "$machine" '.machine.name == $machine and .idle_timeout_minutes == 5 and .retention_period_minutes <= 60 and .retention_period_minutes > 0' "$work/identity.json" >/dev/null || fail 'Codespace allocation does not match requested safeguards.'
# The dynamic heredoc delimiter is checked against the full requested command.
# Test status is read independently because gh ssh may collapse remote exits.
delimiter="COMMAND_$marker"
while case $command in *"$delimiter"*) true;; *) false;; esac; do delimiter="${delimiter}X"; done
remote_status="/tmp/$marker.status"
{
  echo 'set -eu'
  printf 'expected=%s\n' "$sha"
  printf 'cd /workspaces/%s\n' "${repo#*/}"
  echo '[ "$(git rev-parse HEAD)" = "$expected" ] || { echo "Checkout does not match requested commit" >&2; exit 125; }'
  printf "cat > /tmp/%s.command <<'%s'\n" "$marker" "$delimiter"
  printf '%s\n' "$command"
  printf '%s\n' "$delimiter"
  echo 'set +e'
  printf 'sh /tmp/%s.command\n' "$marker"
  printf 'status=$?; printf '\''%%s\\n'\'' "$status" > %s\n' "$remote_status"
  printf 'rm -f /tmp/%s.command\n' "$marker"
  echo 'exit 0'
} >"$work/remote.sh"
start=$(date +%s)
exit_code=0
bounded "$timeout" gh codespace ssh -c "$name" -- -F /dev/null -i "$work/key" -o IdentitiesOnly=yes -o ForwardAgent=no -o ClearAllForwardings=yes -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no sh -s <"$work/remote.sh" >"$output/stdout.log" 2>"$output/stderr.log" || exit_code=$?
duration=$(( $(date +%s) - start ))
if [ "$exit_code" -eq 0 ]; then
  printf 'cat %s\n' "$remote_status" >"$work/read-status.sh"
  if bounded 30 gh codespace ssh -c "$name" -- -F /dev/null -i "$work/key" -o IdentitiesOnly=yes -o ForwardAgent=no -o ClearAllForwardings=yes -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no sh -s <"$work/read-status.sh" >"$work/status" 2>>"$output/stderr.log"; then
    exit_code=$(cat "$work/status")
    case $exit_code in ''|*[!0-9]*) exit_code=1; error='Remote exit status unavailable.';; *) if [ "$exit_code" -le 255 ]; then command_exit_code=$exit_code; else exit_code=1; error='Invalid remote exit status.'; fi;; esac
  else
    exit_code=1; error='Cannot retrieve remote exit status.'
  fi
fi
if [ "$exit_code" -ne 0 ] && [ -z "$error" ]; then error='Remote command failed or execution timed out.'; fi
if [ -n "$artifact" ]; then
  artifact_status=downloaded
  mkdir "$output/artifacts" || fail 'Cannot create artifact directory.'
  bounded 30 gh codespace cp -r -c "$name" -- -F /dev/null -i "$work/key" -o IdentitiesOnly=yes -o ForwardAgent=no -o ClearAllForwardings=yes -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no "remote:/workspaces/${repo#*/}/$artifact" "$output/artifacts/" >"$output/artifact.stdout" 2>"$output/artifact.stderr" || { artifact_status=failed; error='Artifact download failed.'; [ "$exit_code" -ne 0 ] || exit_code=1; }
fi
finish
exit "$exit_code"
