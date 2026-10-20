#!/bin/sh
set -eu
if [ "$#" -ne 2 ]; then echo 'Usage: render.sh state.json output.html' >&2; exit 2; fi
root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
if [ "$1" = "$2" ] || [ "$1" -ef "$2" ]; then echo 'Input and output must differ.' >&2; exit 2; fi
umask 077
tmp=$(mktemp "${2}.tmp.XXXXXX")
trap 'rm -f -- "$tmp"' 0
if ! command -v jq >/dev/null; then
 if [ ! -f "$2" ]; then
  cat "$root/assets/page.html" > "$tmp"
  printf '%s\n' '<h1>Session progress</h1><p>Structured tracking unavailable: jq is missing. See the session chat for progress and final report.</p></main></body></html>' >> "$tmp"
  mv -f -- "$tmp" "$2"
 fi
 echo 'jq unavailable; local static fallback retained.' >&2
 printf '%s\n' "$2"
 exit 0
fi
# Validate one immutable snapshot; reject empty or concatenated JSON documents.
state=$(jq -sc 'if length==1 then .[0] else error("Expected one state object") end' "$1") || exit 2
printf '%s\n' "$state" | jq -e '
 type=="object" and (.title|type=="string") and (.updated|type=="string") and
 (.report|type=="string") and (.blockers|type=="array") and all(.blockers[];type=="string") and
 (.tasks|type=="array") and all(.tasks[]; (.id|type=="string" and length>0) and (.text|type=="string") and (.status as $s|["todo","doing","done","blocked"]|index($s)!=null)) and
 ([.tasks[].id]|length== (unique|length))' >/dev/null || { echo 'Invalid session state.' >&2; exit 2; }
cat "$root/assets/page.html" > "$tmp"
printf '%s\n' "$state" | jq -r '
 "<h1>"+(.title|@html)+"</h1><small>Updated "+(.updated|@html)+" · refreshes every 10 seconds</small>",
 ([.tasks[]|select(.status=="done")]|length) as $done |
 "<p id=summary>"+($done|tostring)+" / "+(.tasks|length|tostring)+" verified complete</p><progress id=progress value=\""+($done|tostring)+"\" max=\""+([(.tasks|length),1]|max|tostring)+"\"></progress>",
 "<section aria-label=Tasks>",
 (.tasks[]|"<label><input type=checkbox"+(if .status=="done" then " checked" else "" end)+"><span>"+(.text|@html)+" <small>"+(.status|@html)+"</small></span></label>"),
 "</section><p id=preview>Checkbox clicks are local previews only; refresh restores agent status.</p><section><h2>Blockers</h2><ul>",
 (if (.blockers|length)==0 then "<li>None reported</li>" else .blockers[]|"<li>"+(@html)+"</li>" end),
 "</ul></section><section><h2>Report</h2><p>"+(.report|@html)+"</p></section>"' >> "$tmp"
cat >> "$tmp" <<'HTML'
</main><script>
const boxes=[...document.querySelectorAll('input[type=checkbox]')];
boxes.forEach(box=>box.addEventListener('change',()=>{
 const n=boxes.filter(b=>b.checked).length;
 document.querySelector('#summary').textContent=`${n} / ${boxes.length} checked (local preview)`;
 document.querySelector('#progress').value=n;
}));
</script></body></html>
HTML
mv -f -- "$tmp" "$2"
printf '%s\n' "$2"
