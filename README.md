# Personal agent skills

Canonical source for reusable personal agent skills. Global agent instructions,
skill source pins, installation and discovery configuration belong to
[`alexcatdad/dotfiles`](https://github.com/alexcatdad/dotfiles). Project-specific
skills remain in their owning projects.

| Skill | Purpose |
| --- | --- |
| `environment-preflight` | Verify task prerequisites on the execution host and intended target. |
| `html-session-progress` | Render a private HTML progress report with optional Tailscale Serve integration. |
| `codespace-sandbox` | Run bounded tests/builds in a disposable GitHub Codespace with a $0-budget check, results, and verified cleanup. |

Each complete package lives in `skills/<name>/`, including its scripts and assets.
Use POSIX sh or Zsh with native Unix utilities; structured HTML rendering needs
`jq`. Codespace execution also requires authenticated `gh`, `jq`, and OpenSSH.
See each `SKILL.md` for task-specific prerequisites and fallback behavior.

## Install and pin

Use a GitHub CLI version that provides `gh skill`. Preview available skills:

```sh
gh skill install alexcatdad/skills
```

Install a reviewed immutable commit (replace the placeholder with its full SHA):

```sh
gh skill install alexcatdad/skills environment-preflight --pin REVIEWED_COMMIT_SHA --dir "$HOME/.agents/skills"
gh skill install alexcatdad/skills html-session-progress --pin REVIEWED_COMMIT_SHA --dir "$HOME/.agents/skills"
gh skill install alexcatdad/skills codespace-sandbox --pin REVIEWED_COMMIT_SHA --dir "$HOME/.agents/skills"
chmod 755 "$HOME/.agents/skills/environment-preflight/scripts/preflight.sh"
chmod 755 "$HOME/.agents/skills/html-session-progress/scripts/render.sh" "$HOME/.agents/skills/html-session-progress/scripts/serve.sh"
chmod 755 "$HOME/.agents/skills/codespace-sandbox/scripts/run.sh"
```

`gh skill` currently writes script files without executable bits. The explicit
mode restoration above applies only to these reviewed scripts.

For an existing dotfiles-managed installation, follow the documented dotfiles
skill migration instead of overwriting the current packages. Its separate GitHub
skill staging and lifecycle migration reconcile prior ownership while preserving
the shared Codex/Gemini location and Claude discovery integration.

Review changes before explicitly installing a newer SHA. Roll back by installing
the previously reviewed SHA after preserving any local modifications. Avoid forced
overwrites of modified or independently owned packages. No startup updates run.

For a disposable local package check:

```sh
skill_fixture=$(mktemp -d)
gh skill install . environment-preflight --from-local --dir "$skill_fixture"
gh skill install . html-session-progress --from-local --dir "$skill_fixture"
gh skill install . codespace-sandbox --from-local --dir "$skill_fixture"
rm -rf -- "$skill_fixture"
```

## Test and contribute

```sh
sh tests/check.sh
gh skill publish --dry-run
```

The checks validate package structure, frontmatter, executable permissions and
shell syntax, then exercise the existing synthetic behavior tests. CI runs on
Linux and macOS. Native Zsh tests run when Zsh is available. These checks do not
establish execution inside every agent client, live Tailscale connectivity, or
live Codespaces provisioning. The Codespaces tests use mocked CLI responses and
synthetic fixtures. Live execution requires separate Codespaces permissions and
a user-confirmed $0 Codespaces budget that stops usage at the limit; without that
confirmation the helper refuses creation. See [the skill](skills/codespace-sandbox/SKILL.md) for invocation
and cleanup recovery.

Keep changes scoped to reusable skills, retain package-relative paths and public
safe synthetic fixtures, and open a pull request with the relevant test results.
Do not add machine state, credentials, histories or agent session data.
