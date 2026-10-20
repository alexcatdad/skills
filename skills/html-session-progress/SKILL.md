---
name: html-session-progress
description: Maintain a lightweight HTML session checklist, progress dashboard, blockers and completion report for multi-step work with tracked tasks, when AGENTS.md requires HTML reporting, or when continuing an existing dashboard. Skip trivial operations needing no tracking and general website development.
compatibility: POSIX sh or Zsh and native Unix utilities; jq for structured rendering. Tailscale Serve and an existing timeout or gtimeout utility are optional for bounded private serving. Windows requires WSL or equivalent supported Linux environment.
---

# HTML session progress

Use `command -v sh` to select `sh`, otherwise `command -v zsh` to select `zsh -f`. Substitute that interpreter in the commands below; direct executable launch uses `/bin/sh`. If neither is available, keep reporting in chat. Do not install a shell or infer availability from `$SHELL`.

Resolve bundled paths relative to this SKILL.md. Spend seconds on reporting; continue the actual task immediately on fallback. Keep one stable private `session-progress/index.html` per workspace, outside publication paths and ephemeral temp directories. Reuse the slot across sessions; archive a prior report locally only when useful. Show only sanitized task labels, results and blockers: exclude secrets, private reasoning, stakeholder commentary, device inventories and private host details.

1. Maintain `state.json` with short tasks and observable completion criteria. Run `sh <skill-dir>/scripts/render.sh state.json index.html`. The helper validates a single JSON object, escapes all text and atomically replaces HTML. Missing jq yields a static local fallback without installation. One writer per dashboard.
2. Update JSON and rerender in the same work step whenever a task changes, completes or becomes blocked. Verify criteria before marking done. The page reloads every ten seconds, including from a local file. Browser checkbox clicks are temporary previews; agent state remains authoritative. No watcher, backend or hook.
3. Try `sh <skill-dir>/scripts/serve.sh /absolute/session-progress/index.html` once. Standing authorization covers safe private tailnet-only dashboards: proceed without repeated approval. The helper reuses an exact persistent route (including another suitable port) or creates one via supported `--bg --yes` on unused port 8443. Use another explicit unprivileged port only if already selected for this workspace. It bounds CLI calls, checks readiness/HTTPS support, rejects public exposure, foreground conflicts and occupied listeners, and falls back locally on unavailable capabilities. It never enables Funnel, installs servers, logs in, changes HTTPS prerequisites or resets Serve. Do not bypass sandbox/client controls. Allow only one Serve configuration writer during setup; the CLI has no atomic compare-and-set.
4. Finish by rendering the concise result, checks and limitations in `report`; return the local link and verified private URL if available. Retain HTML and daemon-managed Serve after the agent exits. No foreground process, recurring agent or polling is needed.

```json
{"title":"Session progress","updated":"2026-01-01T12:00:00Z","tasks":[{"id":"inspect","text":"Inspect workspace","status":"done"},{"id":"verify","text":"Verify result","status":"doing"}],"blockers":[],"report":"Work in progress."}
```

Statuses: `todo`, `doing`, `done`, `blocked`; IDs are unique nonempty strings. `blockers` contains strings. Write text through jq `--arg`, never shell interpolation. Keep state updates atomic when other readers exist.

## Persistence and cleanup

One stable route/file slot avoids accumulating listeners; reuse it next session. Keep the final report accessible until superseded or explicitly retired. No scheduled cleanup or expiry agent. To retire an owned slot, run `sh <skill-dir>/scripts/serve.sh /absolute/session-progress/index.html 8443 retire`. The helper requires its ownership receipt and an unchanged exact handler, removes only that listener, and retains local HTML. Reused routes without ownership are left untouched. Never use `serve reset`. On ambiguous/changed configuration, leave it alone and stay local. The receipt contains private route identity; keep it outside dashboards and version control.

File serving is unsupported by sandboxed macOS Tailscale distributions; use local fallback without a custom server. URLs depend on host/tailnet availability. An installed but unusable client or missing bounded-execution utility is a fallback, not a task blocker. Budget one attempt (at most roughly 20 seconds), no unchanged retries. Do not claim HTTP reachability merely from configured status; when curl is already available, use one `curl --fail --silent --max-time 2` check without printing page contents. Report configured versus reachable accurately.
