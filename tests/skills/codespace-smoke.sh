#!/bin/sh
# Synthetic GitHub CLI contract tests: no live GitHub mutations.
set -eu
root=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' 0
mkdir "$tmp/bin"
export MOCK_DIR="$tmp"
export PATH="$tmp/bin:$PATH"
cat > "$tmp/bin/gh" <<'MOCK'
#!/bin/sh
set -eu
printf '%s\n' "$*" >> "$MOCK_DIR/calls"
case "$*" in
 'auth status'*) [ "$MOCK_CASE" != auth ]; exit ;;
 'api user') printf '%s\n' '{"login":"synthetic"}'; exit ;;
esac
if [ "$1" = api ]; then
 shift
 method=GET
 endpoint=
 input=
 while [ "$#" -gt 0 ]; do
  case "$1" in
   -X|--method) method=$2; shift 2 ;;
   --input) input=$2; shift 2 ;;
   -f|-F|--field|--raw-field|-H|--header|--jq|-q) shift 2 ;;
   --*) shift ;;
   *) [ -n "$endpoint" ] || endpoint=$1; shift ;;
  esac
 done
 case "$endpoint" in
  repos/fixture/repo/commits/*)
   [ "$MOCK_CASE" != ref ] || exit 1
   printf '%s\n' '{"sha":"1111111111111111111111111111111111111111"}';;
  repos/fixture/repo/codespaces/new)
   if [ "$MOCK_CASE" = scope ]; then printf '%s\n' 'gh: This API operation needs the "codespace" scope. To request it, run:  gh auth refresh -h github.com -s codespace' >&2; exit 1; fi
   printf '%s\n' '{"billable_owner":{"login":"synthetic"},"defaults":{"geo":"EuropeWest"}}';;
  users/synthetic/settings/billing/usage)
   [ "$MOCK_CASE" != billing_unavailable ] || exit 1
   printf '%s\n' '{"usageItems":[{"product":"Codespaces","sku":"Codespaces compute 2-core","unitType":"Hours","quantity":1.5,"netAmount":0},{"product":"codespaces","sku":"Codespaces compute 2-core","unitType":"Hours","quantity":0.5,"netAmount":0},{"product":"Codespaces","sku":"Codespaces storage","unitType":"GigabyteHours","quantity":40,"netAmount":0},{"product":"Actions","sku":"Actions Linux","unitType":"Minutes","quantity":90,"netAmount":0}]}';;
  repos/fixture/repo/codespaces/machines)
   printf '%s\n' '{"machines":[{"name":"large","cpus":8,"memory_in_bytes":17179869184,"storage_in_bytes":68719476736},{"name":"small","cpus":2,"memory_in_bytes":4294967296,"storage_in_bytes":34359738368}]}';;
  repos/fixture/repo/codespaces)
   [ "$method" = POST ] || exit 80
   cat "$input" > "$MOCK_DIR/request.json"
   printf '%s\n' create >> "$MOCK_DIR/mutations"
   [ "$MOCK_CASE" != provision ] || exit 1
   [ "$MOCK_CASE" != provision_timeout ] || exec sleep 20
   jq '. + {name:"synthetic-space",prebuild:false,billable_owner:{login:"synthetic"},owner:{login:"synthetic"},repository:{full_name:"fixture/repo"},state:"Available",machine:{name:.machine},git_status:{ref:.ref}}' "$MOCK_DIR/request.json" > "$MOCK_DIR/resource.json"
   [ "$MOCK_CASE" != lost_response ] || exit 1
   cat "$MOCK_DIR/resource.json";;
  user/codespaces/synthetic-space)
   [ -f "$MOCK_DIR/resource.json" ] || exit 1
   case "$MOCK_CASE" in
    ownership) jq '.owner.login="someone-else"' "$MOCK_DIR/resource.json";;
    prebuild) jq '.prebuild=true' "$MOCK_DIR/resource.json";;
    prebuild_null) jq '.prebuild=null' "$MOCK_DIR/resource.json";;
    prebuild_missing) jq 'del(.prebuild)' "$MOCK_DIR/resource.json";;
    safeguards) jq '.idle_timeout_minutes=30' "$MOCK_DIR/resource.json";;
    *) cat "$MOCK_DIR/resource.json";;
   esac;;
  user/codespaces)
   if [ "$MOCK_CASE" = verify_cleanup ] && [ ! -f "$MOCK_DIR/resource.json" ]; then exit 1; fi
   if [ -f "$MOCK_DIR/resource.json" ]; then jq '{codespaces:[.],total_count:1}' "$MOCK_DIR/resource.json"; else printf '%s\n' '{"codespaces":[],"total_count":0}'; fi;;
  *) printf 'unexpected API endpoint: %s\n' "$endpoint" >&2; exit 81;;
 esac
 exit
fi
case "$1 $2" in
 'codespace ssh')
  cat > "$MOCK_DIR/remote.sh"
  case "$MOCK_CASE" in
   timeout|signal) : > "$MOCK_DIR/ssh-started"; exec sleep 20;;
  esac
  [ -s "$MOCK_DIR/remote.sh" ] || { echo 'Remote script stdin was lost' >&2; exit 90; }
  # Replace only the fixture checkout path; execute the real transmitted script.
  sed -e "s|^cd /workspaces/repo$|cd '$MOCK_DIR/checkout'|" -e "s|/tmp/sandbox-|$MOCK_DIR/sandbox-|g" "$MOCK_DIR/remote.sh" > "$MOCK_DIR/executable.sh"
  # Match gh ssh's contract: remote nonzero becomes CLI status 1.
  sh "$MOCK_DIR/executable.sh" || exit 1;;
 'codespace cp')
  printf '%s\n' artifact >> "$MOCK_DIR/mutations"
  [ "$MOCK_CASE" != artifact ] || exit 1
  for arg do destination=$arg; done
  printf 'synthetic artifact\n' > "$destination/result.txt";;
 'codespace delete')
  printf '%s\n' delete >> "$MOCK_DIR/mutations"
  [ "$MOCK_CASE" != cleanup ] || exit 1
  rm -f "$MOCK_DIR/resource.json";;
 *) printf 'unexpected gh command: %s\n' "$*" >&2; exit 82;;
esac
MOCK
chmod +x "$tmp/bin/gh"
mkdir "$tmp/checkout"
cat > "$tmp/bin/git" <<'MOCK'
#!/bin/sh
[ "$*" = 'rev-parse HEAD' ] || exit 91
if [ "$MOCK_CASE" = wrong_commit ]; then printf '%040d\n' 2; else printf '%s\n' 1111111111111111111111111111111111111111; fi
MOCK
chmod +x "$tmp/bin/git"
runner=$root/skills/codespace-sandbox/scripts/run.sh
run_case() {
 MOCK_CASE=$1
 export MOCK_CASE
 shift
 rm -f "$tmp/resource.json" "$tmp/calls" "$tmp/mutations" "$tmp/request.json" "$tmp/remote.sh" "$tmp/ssh-started"
 output="$tmp/result-$MOCK_CASE"
 rm -rf "$output"
 if [ "$MOCK_CASE" = signal ]; then
  # Wait until the synthetic remote command starts, then interrupt only this runner.
  (while [ ! -f "$tmp/ssh-started" ]; do sleep 0.05; done; kill -TERM "$(cat "$tmp/runner.pid")") &
  interrupter=$!
 fi
 set +e
 sh "$runner" --repo fixture/repo --ref feature --command 'printf "synthetic success\n"' --billing-owner synthetic --zero-budget-confirmed --output "$output" "$@" > "$tmp/stdout" 2> "$tmp/stderr" &
 runner_pid=$!
 echo "$runner_pid" > "$tmp/runner.pid"
 wait "$runner_pid"; status=$?
 if [ "$MOCK_CASE" = signal ]; then kill "$interrupter" 2>/dev/null || :; wait "$interrupter" 2>/dev/null || :; fi
 set -e
}
no_creation() { [ ! -f "$tmp/mutations" ] || ! grep -q '^create$' "$tmp/mutations"; }
cleaned() { [ ! -f "$tmp/resource.json" ]; grep -q '^delete$' "$tmp/mutations"; }
run_case auth
[ "$status" -ne 0 ]; no_creation
jq -e '.cleanup == "not_created" and .command_exit_code == null and .estimated_usage.core_hours == null' "$output/result.json" >/dev/null
run_case ref
[ "$status" -ne 0 ]; no_creation
run_case invalid_repo --repo fixture/missing
[ "$status" -ne 0 ]; no_creation
run_case machine --machine absent
[ "$status" -ne 0 ]; no_creation
run_case old_budget_flag --included-core-hours 10
[ "$status" -eq 2 ]; no_creation
grep -q 'replaced by --zero-budget-confirmed' "$tmp/stderr"
run_case missing_budget --billing-owner ''
[ "$status" -ne 0 ]; no_creation
# The budget confirmation is required; run_case always passes it.
MOCK_CASE=missing_confirmation; export MOCK_CASE
rm -f "$tmp/mutations"; output="$tmp/result-missing_confirmation"
set +e
sh "$runner" --repo fixture/repo --ref feature --command true --billing-owner synthetic --output "$output" > "$tmp/stdout" 2> "$tmp/stderr"; status=$?
set -e
[ "$status" -ne 0 ]; no_creation
jq -e '.cleanup == "not_created" and (.error | contains("--zero-budget-confirmed"))' "$output/result.json" >/dev/null
run_case owner --billing-owner unknown
[ "$status" -ne 0 ]; no_creation
run_case scope
[ "$status" -ne 0 ]; no_creation
jq -e '.error | startswith("Cannot establish Codespaces billing ownership. Cause: gh: This API operation needs the \"codespace\" scope")' "$output/result.json" >/dev/null
grep -q 'needs the "codespace" scope' "$output/preflight-options.stderr"
run_case provision
[ "$status" -ne 0 ]; [ ! -f "$tmp/resource.json" ]
run_case provision_timeout --provision-timeout 1
[ "$status" -ne 0 ]; [ ! -f "$tmp/resource.json" ]
run_case lost_response
[ "$status" -ne 0 ]; cleaned
run_case success
[ "$status" -eq 0 ]; cleaned
jq -e '.ref == "1111111111111111111111111111111111111111" and .machine == "small" and .idle_timeout_minutes == 5' "$tmp/request.json" >/dev/null
jq -e '.commit == "1111111111111111111111111111111111111111" and .cleanup == "deleted" and .exit_code == 0 and .estimated_usage.actual_billing == false' "$output/result.json" >/dev/null
grep -q '^synthetic success$' "$output/stdout.log"
jq -e '.reported_usage.items == [{"sku":"Codespaces compute 2-core","unit_type":"Hours","quantity":2,"net_amount":0},{"sku":"Codespaces storage","unit_type":"GigabyteHours","quantity":40,"net_amount":0}] and (.reported_usage.period | test("^[0-9]{4}-[0-9]{2}$"))' "$output/result.json" >/dev/null
run_case billing_unavailable
[ "$status" -eq 0 ]; cleaned
jq -e '.reported_usage == null' "$output/result.json" >/dev/null
run_case wrong_commit
[ "$status" -ne 0 ]; cleaned
! grep -q '^synthetic success$' "$output/stdout.log"
literal_command=$(cat <<'COMMAND'
printf '%s\n' 'quotes "double" and '\''single'\''; $(literal), `literal`, $HOME'
cat <<'INNER'
CODESPACE_SANDBOX_COMMAND_EOF
INNER
COMMAND
)
run_case literal --command "$literal_command"
[ "$status" -eq 0 ]; cleaned
printf '%s\n' 'quotes "double" and '\''single'\''; $(literal), `literal`, $HOME' CODESPACE_SANDBOX_COMMAND_EOF > "$tmp/expected"
cmp "$tmp/expected" "$output/stdout.log"
run_case command --command 'printf "synthetic failure\n" >&2; exit 23'
[ "$status" -eq 23 ]; cleaned
jq -e '.command_exit_code == 23 and .remaining_resources == []' "$output/result.json" >/dev/null
run_case timeout --timeout 1
[ "$status" -eq 124 ]; cleaned
run_case signal
[ "$status" -eq 143 ]; cleaned
run_case artifact --artifact results.txt
[ "$status" -ne 0 ]; cleaned
jq -e '.command_exit_code == 0 and .artifact_status == "failed"' "$output/result.json" >/dev/null
run_case artifact_success --artifact results.txt
[ "$status" -eq 0 ]; cleaned
[ -s "$output/artifacts/result.txt" ]
jq -e '.artifact_status == "downloaded"' "$output/result.json" >/dev/null
run_case prebuild
[ "$status" -ne 0 ]; cleaned
run_case prebuild_null
[ "$status" -eq 0 ]; cleaned
run_case prebuild_missing
[ "$status" -ne 0 ]; cleaned
run_case safeguards
[ "$status" -ne 0 ]; cleaned
run_case cleanup
[ "$status" -ne 0 ]; [ -f "$tmp/resource.json" ]
jq -e '.command_exit_code == 0 and .remaining_resources == ["synthetic-space"]' "$output/result.json" >/dev/null
cat "$tmp/stdout" "$tmp/stderr" "$output"/* > "$tmp/combined" 2>/dev/null || true
grep -q 'gh codespace delete.*synthetic-space' "$tmp/combined"
run_case verify_cleanup
[ "$status" -ne 0 ]
jq -e '.cleanup != "deleted"' "$output/result.json" >/dev/null
run_case ownership
[ "$status" -ne 0 ]; [ -f "$tmp/resource.json" ]
! grep -q '^delete$' "$tmp/mutations"
for repetition in 1 2 3; do run_case success; [ "$status" -eq 0 ]; cleaned; done
printf '%s\n' 'PASS: mocked authentication, preflight diagnostics, billing usage, prebuild status, refs, machines, budget confirmation, ownership, provisioning, execution, timeout, artifacts, cleanup and repeated runs.'
