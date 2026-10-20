#!/bin/sh
set -eu
test_shell=${TEST_SHELL:-$(command -v sh)}

root=$(CDPATH='' cd -- "$(dirname -- "$0")/../../skills" && pwd)
tmp=$(mktemp -d)
ZDOTDIR=$tmp
export ZDOTDIR

trap 'rm -rf -- "$tmp"' 0
render=$root/html-session-progress/scripts/render.sh
preflight=$root/environment-preflight/scripts/preflight.sh
for script in "$render" "$preflight"; do "$test_shell" -n "$script"; done
"$test_shell" "$preflight" > "$tmp/defaults"
grep -q result=requested-local-checks-passed "$tmp/defaults"
container=synthetic "$test_shell" "$preflight" > "$tmp/container"
grep -q container_signal=detected "$tmp/container"

# Deliberately malicious text must remain inert in generated HTML.
cat > "$tmp/state.json" <<'JSON'
{"title":"<script>alert(1)</script>","updated":"now","tasks":[{"id":"a","text":"A & B","status":"done"},{"id":"b","text":"<img src=x onerror=alert(2)>","status":"blocked"}],"blockers":["Await input"],"report":"Test only"}
JSON
"$test_shell" "$render" "$tmp/state.json" "$tmp/index.html" >/dev/null
grep -q '&lt;script&gt;' "$tmp/index.html"
grep -q '&lt;img src=x' "$tmp/index.html"
grep -q '1 / 2 verified' "$tmp/index.html"
jq '.tasks[1].status="done"' "$tmp/state.json" > "$tmp/next.json"
"$test_shell" "$render" "$tmp/next.json" "$tmp/index.html" >/dev/null
grep -q '2 / 2 verified' "$tmp/index.html"
cp "$tmp/index.html" "$tmp/preserved.html"
printf '{}\n' > "$tmp/bad.json"
if "$test_shell" "$render" "$tmp/bad.json" "$tmp/index.html" 2>/dev/null; then exit 1; fi
cmp "$tmp/index.html" "$tmp/preserved.html"
jq '.tasks[1].id="a"' "$tmp/state.json" > "$tmp/duplicate.json"
if "$test_shell" "$render" "$tmp/duplicate.json" "$tmp/index.html" 2>/dev/null; then exit 1; fi
jq '.tasks=[]' "$tmp/state.json" > "$tmp/empty.json"
"$test_shell" "$render" "$tmp/empty.json" "$tmp/index.html" >/dev/null
grep -q '0 / 0 verified' "$tmp/index.html"
"$test_shell" "$preflight" --workspace "$tmp" --target current --tool sh > "$tmp/preflight"
grep -q 'tool:sh=available' "$tmp/preflight"
if "$test_shell" "$preflight" --tool nonexistent-task-tool-98765 > "$tmp/missing"; then exit 1; else [ "$?" -eq 1 ]; fi
if "$test_shell" "$preflight" --workspace "$tmp/missing-dir" > /dev/null; then exit 1; else [ "$?" -eq 1 ]; fi
SMOKE_SECRET=synthetic-secret "$test_shell" "$preflight" --credential-env SMOKE_SECRET > "$tmp/credential"
grep -q 'present-unverified' "$tmp/credential"
if grep -q synthetic-secret "$tmp/credential"; then exit 1; fi
if env -u SMOKE_ABSENT "$test_shell" "$preflight" --credential-env SMOKE_ABSENT >/dev/null; then exit 1; else [ "$?" -eq 1 ]; fi
if "$test_shell" "$preflight" --tool 'sh;echo unsafe' >/dev/null 2>&1; then exit 1; else [ "$?" -eq 2 ]; fi
SSH_CONNECTION=synthetic "$test_shell" "$preflight" --target remote > "$tmp/ssh"
grep -q 'ssh_signal=present' "$tmp/ssh"
grep -q 'target_readiness=requires-separate-confirmation' "$tmp/ssh"
for skill in html-session-progress environment-preflight; do
 file=$root/$skill/SKILL.md
 [ "$(head -1 "$file")" = --- ]
 [ "$(sed -n '2p' "$file")" = "name: $skill" ]
 awk '/^description: / { if(length($0)<=13 || length($0)>1037) exit 1; found=1 } END { if(!found) exit 1 }' "$file"
done
echo 'PASS: render/update/escaping/validation/empty tasks; host/tools/credentials/SSH/remote/errors; minimal frontmatter.'
# Every legal transition, invalid status, malformed and concatenated documents.
for task_status in todo doing blocked "done" todo; do
 jq --arg status "$task_status" '.tasks[0].status=$status' "$tmp/state.json" > "$tmp/transition.json"
 "$test_shell" "$render" "$tmp/transition.json" "$tmp/index.html" >/dev/null
 grep -q ">$task_status</small>" "$tmp/index.html"
done
cp "$tmp/index.html" "$tmp/preserved.html"
for invalid in '{' 'null' ''; do
 printf '%s' "$invalid" > "$tmp/invalid.json"
 if "$test_shell" "$render" "$tmp/invalid.json" "$tmp/index.html" 2>/dev/null; then exit 1; fi
 cmp "$tmp/index.html" "$tmp/preserved.html"
done
cat "$tmp/state.json" "$tmp/state.json" > "$tmp/multiple.json"
if "$test_shell" "$render" "$tmp/multiple.json" "$tmp/index.html" 2>/dev/null; then exit 1; fi
jq '.tasks[0].status="invalid"' "$tmp/state.json" > "$tmp/invalid.json"
if "$test_shell" "$render" "$tmp/invalid.json" "$tmp/index.html" 2>/dev/null; then exit 1; fi
cmp "$tmp/index.html" "$tmp/preserved.html"
[ -z "$(find "$tmp" -name '*.tmp.*' -print)" ]
"$test_shell" "$preflight" --writable "$tmp" > "$tmp/write"
grep -q required_write=verified "$tmp/write"
if "$test_shell" "$preflight" --writable "$tmp/not-present" >/dev/null; then exit 1; else [ "$?" -eq 1 ]; fi
[ -z "$(find "$tmp" -name '.preflight.*' -print)" ]
# Isolated PATH: jq absence falls back with no install; reuse previous HTML.
mkdir "$tmp/native"
for tool in dirname pwd mktemp cat mv rm basename; do
 tool_path=$(command -v "$tool")
 if [ -f "$tool_path" ]; then ln -s "$tool_path" "$tmp/native/$tool"; fi
done
PATH="$tmp/native" "$test_shell" "$render" "$tmp/state.json" "$tmp/fallback.html" 2>/dev/null >/dev/null
grep -q 'jq is missing' "$tmp/fallback.html"
PATH="$tmp/native" "$test_shell" "$render" "$tmp/state.json" "$tmp/index.html" 2>/dev/null >/dev/null
cmp "$tmp/index.html" "$tmp/preserved.html"
PATH="$tmp/native" "$test_shell" "$root/html-session-progress/scripts/serve.sh" "$tmp/index.html" > "$tmp/local"
grep -q '^local:' "$tmp/local"
# Unsupported OS degrades to explicit failure without unrelated checks.
printf '#!/bin/sh\necho UnsupportedOS\n' > "$tmp/native/uname"
chmod +x "$tmp/native/uname"
if PATH="$tmp/native" "$test_shell" "$preflight" > "$tmp/unsupported"; then exit 1; else [ "$?" -eq 1 ]; fi
grep -q unsupported-environment "$tmp/unsupported"
echo 'PASS: all status transitions, malformed/multiple JSON, failed-update atomicity, no temporary leaks, permission probes, missing jq/Tailscale and unsupported host.'
ln -s "$(command -v jq)" "$tmp/native/jq"
printf '#!/bin/sh\nexit 99\n' > "$tmp/native/tailscale"
chmod +x "$tmp/native/tailscale"
PATH="$tmp/native" "$test_shell" "$root/html-session-progress/scripts/serve.sh" "$tmp/index.html" > "$tmp/bounded"
grep -q 'bounded CLI execution unavailable' "$tmp/bounded"
echo 'PASS: missing timeout capability stays local without invoking Tailscale.'
# Bootstrap with only native utilities and Zsh discoverable in PATH.
if command -v zsh >/dev/null 2>&1; then
 mkdir "$tmp/bootstrap"
 for tool in uname hostname printenv mktemp rm zsh; do
  tool_path=$(command -v "$tool")
  ln -s "$tool_path" "$tmp/bootstrap/$tool"
 done
 SMOKE_SECRET=synthetic-secret PATH="$tmp/bootstrap" "$test_shell" "$preflight" --credential-env SMOKE_SECRET > "$tmp/bootstrap-result"
 grep -q 'shell:sh=missing' "$tmp/bootstrap-result"
 grep -q 'shell:zsh=available' "$tmp/bootstrap-result"
 grep -q 'present-unverified' "$tmp/bootstrap-result"
 echo 'PASS: preflight bootstrap with only Zsh and native utilities discoverable.'
fi
