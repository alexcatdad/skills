#!/bin/sh
set -eu
workspace=$PWD target=unknown failed=0
usage() { echo 'Usage: preflight.sh [--workspace DIR] [--target current|remote|unknown] [--tool NAME] [--credential-env NAME] [--writable DIR]' >&2; exit 2; }
# Validate first, then revisit the original argument list without arrays or eval.
validate() {
 while [ "$#" -gt 0 ]; do
  [ "$#" -ge 2 ] || usage
  case "$1" in
   --workspace) workspace=$2 ;;
   --target) target=$2; case "$target" in current|remote|unknown) ;; *) usage ;; esac ;;
   --tool) case "$2" in ''|[!a-zA-Z0-9_]*|*[!a-zA-Z0-9_.+-]*) usage ;; esac ;;
   --credential-env) case "$2" in ''|[!a-zA-Z_]*|*[!a-zA-Z0-9_]*) usage ;; esac ;;
   --writable) ;;
   *) usage ;;
  esac
  shift 2
 done
}
validate "$@"
os=$(uname -s) arch=$(uname -m)
case "$os" in Darwin|Linux) ;; *) echo 'result=unsupported-environment; use client-native task checks'; exit 1 ;; esac
printf 'os=%s\narch=%s\nhost=%s\ntarget=%s\n' "$os" "$arch" "$(hostname)" "$target"
# SHELL identifies a configured login shell, not necessarily this interpreter.
if [ -n "${ZSH_VERSION-}" ]; then echo execution_shell=zsh; else echo execution_shell=sh-compatible; fi
for shell_name in sh zsh; do
 if command -v "$shell_name" >/dev/null 2>&1; then printf 'shell:%s=available\n' "$shell_name"; else printf 'shell:%s=missing\n' "$shell_name"; fi
done
printf 'ssh_signal=%s\n' "$(if [ -n "${SSH_CONNECTION:-}${SSH_TTY:-}" ]; then echo present; else echo absent; fi)"
container_signal=unknown
if [ -f /.dockerenv ] || [ -f /run/.containerenv ] || [ -n "${container:-}" ]; then container_signal=detected; fi
vm=unknown
if command -v systemd-detect-virt >/dev/null 2>&1; then
 if systemd-detect-virt --container --quiet 2>/dev/null; then container_signal=detected; fi
 if systemd-detect-virt --vm --quiet 2>/dev/null; then vm=detected; fi
elif [ "$os" = Darwin ] && command -v sysctl >/dev/null 2>&1; then
 if [ "$(sysctl -n kern.hv_vmm_present 2>/dev/null || true)" = 1 ]; then vm=detected; fi
fi
printf 'container_signal=%s\nvm_signal=%s\n' "$container_signal" "$vm"
if [ -d "$workspace" ] && [ -r "$workspace" ] && [ -x "$workspace" ]; then echo workspace_access=readable; else echo workspace_access=missing-or-denied; failed=1; fi
if [ -w "$workspace" ]; then echo workspace_write=advisory-yes; else echo workspace_write=advisory-no; fi
while [ "$#" -gt 0 ]; do
 case "$1" in
  --tool)
   if command -v "$2" >/dev/null 2>&1; then printf 'tool:%s=available\n' "$2"; else printf 'tool:%s=missing\n' "$2"; failed=1; fi ;;
  --credential-env)
   if ! command -v printenv >/dev/null 2>&1; then printf 'credential:%s=check-unavailable\n' "$2"; failed=1
   elif [ -n "$(printenv "$2" 2>/dev/null || true)" ]; then printf 'credential:%s=present-unverified\n' "$2"
   else printf 'credential:%s=missing\n' "$2"; failed=1; fi ;;
  --writable)
   if [ -d "$2" ] && probe=$(mktemp "$2/.preflight.XXXXXX" 2>/dev/null); then
    rm -f "$probe"
    echo required_write=verified
   else echo required_write=denied-or-missing; failed=1; fi ;;
 esac
 shift 2
done
if [ "$target" != current ]; then echo target_readiness=requires-separate-confirmation; fi
if [ "$failed" -eq 0 ]; then echo result=requested-local-checks-passed; else echo result=blocked-prerequisite; fi
exit "$failed"
