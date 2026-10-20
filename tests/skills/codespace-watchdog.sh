#!/bin/sh
# Reproduce the fast-command cancellation race using the actual runner helper.
set -eu
root=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' 0
runner=$root/skills/codespace-sandbox/scripts/run.sh
awk '/^bounded\(\) \{/ { copying=1 } /^api\(\)/ { copying=0 } copying { print }' "$runner" > "$tmp/helper.sh"
[ -s "$tmp/helper.sh" ]
cat > "$tmp/probe.sh" <<'PROBE'
#!/bin/sh
set -u
work=$1
sequence=0
child= watchdog=
# Match the runner's inherited signal handler, which exposes the Dash race.
trap 'exit 143' TERM
. "$2"
iteration=0
while [ "$iteration" -lt 100 ]; do
  bounded 1 : || { echo 'Fast command was incorrectly reported as timed out.' >&2; exit 1; }
  iteration=$((iteration + 1))
done
bounded 2 sh -c 'exit 23'
status=$?
[ "$status" -eq 23 ] || exit 1
bounded 1 sleep 3 2>"$work/timeout.stderr"
status=$?
[ "$status" -eq 124 ] || exit 1
# Delay initialization to make cancellation before trap installation repeatable.
. "$3"
bounded 1 : || { echo 'Cancellation before watchdog initialization was lost.' >&2; exit 1; }
PROBE
awk '{ if ($0 == "    sleeper=") print "    sleep 1"; print }' "$tmp/helper.sh" > "$tmp/delayed-helper.sh"
run_shell() {
  mkdir "$tmp/work-$1"
  "$2" "$tmp/probe.sh" "$tmp/work-$1" "$tmp/helper.sh" "$tmp/delayed-helper.sh"
}
run_shell default "${WATCHDOG_TEST_SHELL:-sh}"
if [ -z "${WATCHDOG_TEST_SHELL:-}" ] && command -v dash >/dev/null 2>&1; then
  run_shell dash "$(command -v dash)"
fi
echo 'PASS: watchdog cancellation before initialization, fast commands, command status and timeout.'
