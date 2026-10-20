#!/bin/sh
set -eu
test_shell=${TEST_SHELL:-$(command -v sh)}

root=$(CDPATH='' cd -- "$(dirname -- "$0")/../../skills" && pwd)
tmp=$(mktemp -d)
ZDOTDIR=$tmp
export ZDOTDIR

trap 'rm -rf -- "$tmp"' 0
mkdir "$tmp/bin"
export MOCK_DIR="$tmp"
cat > "$tmp/bin/timeout" <<'SH'
#!/bin/sh
shift 3
exec "$@"
SH
cat > "$tmp/bin/tailscale" <<'SH'
#!/bin/sh
set -eu
case "$*" in
 'status --json') printf '%s\n' '{"BackendState":"Running","Self":{"DNSName":"synthetic.test.ts.net."},"CertDomains":["synthetic.test.ts.net"]}' ;;
 'serve status --json') cat "$MOCK_DIR/config" ;;
 'serve --help') printf '%s\n' '--bg --yes --https' ;;
 'serve --bg --yes --https=8443 '*)
  echo create >> "$MOCK_DIR/mutations"
  [ "${MOCK_FAIL:-0}" = 0 ] || exit 1
  jq --arg path "$5" '.TCP["8443"]={HTTPS:true}|.Web["synthetic.test.ts.net:8443"]={Handlers:{"/":{Path:$path}}}' "$MOCK_DIR/config" > "$MOCK_DIR/next"
  mv "$MOCK_DIR/next" "$MOCK_DIR/config" ;;
 'serve --https=8443 off')
  echo retire >> "$MOCK_DIR/mutations"
  jq 'del(.TCP["8443"],.Web["synthetic.test.ts.net:8443"])' "$MOCK_DIR/config" > "$MOCK_DIR/next"
  mv "$MOCK_DIR/next" "$MOCK_DIR/config" ;;
 *) echo unexpected >> "$MOCK_DIR/mutations"; exit 1 ;;
 esac
SH
chmod +x "$tmp/bin/"*
export PATH="$tmp/bin:$PATH"
serve=$root/html-session-progress/scripts/serve.sh
printf '<html>synthetic</html>\n' > "$tmp/index.html"
printf '%s\n' '{"TCP":{"443":{"HTTPS":true}},"Web":{"synthetic.test.ts.net:443":{"Handlers":{"/":{"Proxy":"http://127.0.0.1:9999"}}}}}' > "$tmp/config"
jq '{TCP:{"443":.TCP["443"]},Web:{"synthetic.test.ts.net:443":.Web["synthetic.test.ts.net:443"]}}' "$tmp/config" > "$tmp/unrelated"
"$test_shell" "$serve" "$tmp/index.html" > "$tmp/result"
grep -q '^https://' "$tmp/result"
[ "$(cat "$tmp/mutations")" = create ]
[ -f "$tmp/index.html.serve-owner.json" ]
jq '{TCP:{"443":.TCP["443"]},Web:{"synthetic.test.ts.net:443":.Web["synthetic.test.ts.net:443"]}}' "$tmp/config" > "$tmp/check"
cmp "$tmp/unrelated" "$tmp/check"
# A second invocation reuses a persistent route without mutation.
"$test_shell" "$serve" "$tmp/index.html" >/dev/null
[ "$(cat "$tmp/mutations")" = create ]
# Conflicting targets cannot be replaced.
printf '<html>other</html>\n' > "$tmp/other.html"
"$test_shell" "$serve" "$tmp/other.html" > "$tmp/result"
grep -q 'listener occupied' "$tmp/result"
# Changed routes cannot be retired.
jq '.Web["synthetic.test.ts.net:8443"].Handlers["/extra"]={Text:"other"}' "$tmp/config" > "$tmp/next"
mv "$tmp/next" "$tmp/config"
"$test_shell" "$serve" "$tmp/index.html" 8443 retire > "$tmp/result"
grep -q 'no unchanged owned route' "$tmp/result"
[ "$(cat "$tmp/mutations")" = create ]
jq 'del(.Web["synthetic.test.ts.net:8443"].Handlers["/extra"])' "$tmp/config" > "$tmp/next"
mv "$tmp/next" "$tmp/config"
"$test_shell" "$serve" "$tmp/index.html" 8443 retire > /dev/null
[ "$(tail -1 "$tmp/mutations")" = retire ]
[ -f "$tmp/index.html" ] && [ ! -f "$tmp/index.html.serve-owner.json" ]
# Public/foreground/unknown configurations fail closed without mutations.
for config in '{"AllowFunnel":{"synthetic.test.ts.net:443":true}}' '{"Foreground":{"session":{"TCP":{"8443":{"HTTPS":true}}}}}' '{"Unknown":true}'; do
 printf '%s\n' "$config" > "$tmp/config"
 "$test_shell" "$serve" "$tmp/index.html" > "$tmp/result"
 grep -q '^local:' "$tmp/result"
 [ "$(wc -l < "$tmp/mutations" | tr -d ' ')" = 2 ]
done
printf '{}\n' > "$tmp/config"
MOCK_FAIL=1 "$test_shell" "$serve" "$tmp/index.html" > "$tmp/result"
grep -q 'file serving unavailable' "$tmp/result"
echo 'PASS: mocked persistent creation/reuse, conflicts, Funnel/unknown rejection, scoped retirement, unsupported serving; unrelated routes preserved.'
# Prefer a suitable pre-existing listener even when it uses a different port.
jq -n --arg path "$tmp/index.html" '{TCP:{"9443":{HTTPS:true}},Web:{"synthetic.test.ts.net:9443":{Handlers:{"/":{Path:$path}}}}}' > "$tmp/config"
before=$(cat "$tmp/mutations")
"$test_shell" "$serve" "$tmp/index.html" > "$tmp/result"
grep -q ':9443/' "$tmp/result"
[ "$(cat "$tmp/mutations")" = "$before" ]
# A second hostname on the same listener prevents an exact owned match.
jq -n --arg path "$tmp/index.html" '{TCP:{"8443":{HTTPS:true}},Web:{"synthetic.test.ts.net:8443":{Handlers:{"/":{Path:$path}}},"other.test.ts.net:8443":{Handlers:{"/":{Text:"unrelated"}}}}}' > "$tmp/config"
jq -n --arg file "$tmp/index.html" '{file:$file,host:"synthetic.test.ts.net",port:"8443"}' > "$tmp/index.html.serve-owner.json"
"$test_shell" "$serve" "$tmp/index.html" 8443 retire > "$tmp/result"
grep -q 'no unchanged owned route' "$tmp/result"
[ "$(cat "$tmp/mutations")" = "$before" ]
echo 'PASS: existing alternate listener reused; shared-listener cleanup refused.'
