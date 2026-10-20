#!/bin/sh
# Optional, persistent tailnet serving. Never installs or enables prerequisites.
set -eu
[ "$#" -ge 1 ] && [ "$#" -le 3 ] || { echo 'Usage: serve.sh index.html [port=8443] [retire]' >&2; exit 2; }
file=$1 port=${2:-8443} mode=${3:-serve}
case "$port" in ''|*[!0-9]*) exit 2 ;; esac
[ "$port" -ge 1024 ] && [ "$port" -le 65535 ] || exit 2
case "$mode" in serve|retire) ;; *) exit 2 ;; esac
[ -f "$file" ] && [ ! -L "$file" ] || { echo 'local: dashboard unavailable'; exit 0; }
file=$(CDPATH='' cd -- "$(dirname -- "$file")" && printf '%s/%s' "$PWD" "$(basename -- "$file")")
fallback() { printf 'local: %s (%s)\n' "$file" "$1"; exit 0; }
for tool in jq tailscale; do command -v "$tool" >/dev/null || fallback "$tool unavailable"; done
# No watchdog process: use an existing bounded-command utility, or stay local.
if command -v timeout >/dev/null; then timer=timeout
elif command -v gtimeout >/dev/null; then timer=gtimeout
else fallback 'bounded CLI execution unavailable'; fi
run() { "$timer" -k 1 2 tailscale "$@" </dev/null 2>/dev/null; }
node=$(run status --json) || fallback 'Tailscale unavailable'
printf '%s\n' "$node" | jq -e '.BackendState=="Running" and (.Self.DNSName|type=="string")' >/dev/null || fallback 'Tailscale not ready'
host=$(printf '%s\n' "$node" | jq -r '.Self.DNSName|rtrimstr(".")')
case "$host" in ''|*[!a-zA-Z0-9.-]*) fallback 'unknown host format' ;; esac
config=$(run serve status --json) || fallback 'Serve unavailable'
# Fail closed on unknown top-level schema or public exposure anywhere.
safe() {
 printf '%s\n' "$1" | jq -e 'type=="object" and (keys-["TCP","Web","AllowFunnel","Foreground","ETag"]|length==0) and
 all(..|objects|.AllowFunnel? // {}|.[]; .==false)' >/dev/null 2>&1
}
safe "$config" || fallback 'unsupported or public Serve configuration'
exact() {
 printf '%s\n' "$1" | jq -e --arg key "$host:$port" --arg port "$port" --arg file "$file" '
 .TCP[$port]=={"HTTPS":true} and .Web[$key]=={"Handlers":{"/":{"Path":$file}}} and
 ([.Web|keys[]|select(endswith(":"+$port))]==[$key]) and
 all((.Foreground // {})[]; (.TCP[$port] // null)==null and
 ((.Web // {})|keys|all(.[]; endswith(":"+$port)|not)))' >/dev/null 2>&1
}
owner="${file}.serve-owner.json"
if [ "$mode" = retire ]; then
 if [ ! -f "$owner" ] || ! exact "$config"; then fallback 'no unchanged owned route to retire'; fi
 jq -e --arg file "$file" --arg host "$host" --arg port "$port" '.=={file:$file,host:$host,port:$port}' "$owner" >/dev/null || fallback 'ownership mismatch'
 run serve --https="$port" off >/dev/null || fallback 'retirement unavailable'
 rm -f -- "$owner"
 fallback 'owned route retired; local report retained'
fi
# With no explicit port, prefer any suitable existing persistent HTTPS listener.
if [ "$#" -eq 1 ]; then
 requested_port=$port
 for candidate in $(printf '%s\n' "$config" | jq -r --arg host "$host" --arg file "$file" '.Web // {}|to_entries[]|select(.key|startswith($host+":"))|select(.value=={Handlers:{"/":{Path:$file}}})|.key|split(":")[-1]'); do
  case "$candidate" in ''|*[!0-9]*) continue ;; esac
   port=$candidate
   if exact "$config"; then printf 'https://%s:%s/\n' "$host" "$port"; exit 0; fi
 done
 port=$requested_port
fi
if exact "$config"; then printf 'https://%s:%s/\n' "$host" "$port"; exit 0; fi
# Never share a listener: includes foreground sessions and Funnel reservations.
printf '%s\n' "$config" | jq -e --arg port "$port" 'all(..|objects;
 ((.TCP? // {})|has($port)|not) and
 ((.Web? // {})|keys|all(.[]; endswith(":"+$port)|not)) and
 ((.AllowFunnel? // {})|keys|all(.[]; endswith(":"+$port)|not)))' >/dev/null || fallback 'listener occupied'
# No HTTPS setup/login prompts; capability must already be enabled for this host.
printf '%s\n' "$node" | jq -e --arg host "$host" '(.CertDomains // [])|index($host)!=null' >/dev/null || fallback 'HTTPS unavailable'
help=$(run serve --help) || fallback 'Serve unsupported'
case "$help" in *--bg*) ;; *) fallback 'persistent noninteractive Serve unsupported' ;; esac
case "$help" in *--yes*) ;; *) fallback 'persistent noninteractive Serve unsupported' ;; esac
# CLI has no atomic compare-and-set; require one Serve writer during this step.
fresh=$(run serve status --json) || fallback 'Serve unavailable'
[ "$(printf '%s\n' "$fresh" | jq -cS .)" = "$(printf '%s\n' "$config" | jq -cS .)" ] || fallback 'configuration changed'
run serve --bg --yes --https="$port" "$file" >/dev/null || fallback 'file serving unavailable'
# Record only our new route; retire never acts on unowned or altered handlers.
umask 077
tmp=$(mktemp "${owner}.tmp.XXXXXX")
trap 'rm -f -- "$tmp"' 0
jq -n --arg file "$file" --arg host "$host" --arg port "$port" '{file:$file,host:$host,port:$port}' > "$tmp"
mv -f -- "$tmp" "$owner"
after=$(run serve status --json) || fallback 'route created; verification unavailable (ownership recorded)'
if ! safe "$after" || ! exact "$after"; then fallback 'route created; configuration differs (ownership recorded)'; fi
printf 'https://%s:%s/\n' "$host" "$port"
