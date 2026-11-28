# Personal agent skills

Canonical source for reusable personal agent skills. Project-specific skills
belong in their owning projects.

| Skill | Purpose |
| --- | --- |
| `realistic-3d-modeling` | Build orbitable 3D assets from references and verify their appearance through matched renders and independent visual review. |
| `agent-instructions` | Write and edit agent-facing instructions as keyword statements, and place each rule in the global file, a skill or a hook. |
| `tool-selection` | Research and recommend a tool, library, language or stack before one is chosen. |
| `clarify` | Settle goal, scope and done-criteria one question at a time before building. |
| `artifact` | Create a private native artifact for live progress, dashboards, visuals, or reports. Invoke with `$artifact` in Codex or `/artifact` in Claude Code once configured. |
| `codespace-sandbox` | Run bounded tests/builds in a disposable GitHub Codespace with a $0-budget check, results, and verified cleanup. |

Each complete package lives in `skills/<name>/`, including its scripts and assets.
Codespace execution uses POSIX sh with native Unix utilities, authenticated
`gh`, `jq`, and OpenSSH.
See each `SKILL.md` for task-specific prerequisites and fallback behavior.

## Install and pin

Choose a version from [stable releases](https://github.com/alexcatdad/skills/releases/latest),
then pin the full commit SHA for that release. The skills are licensed under
the [MIT License](LICENSE).

Use a GitHub CLI version that provides `gh skill`. Preview available skills:

```sh
gh skill install alexcatdad/skills
```

Install a reviewed immutable commit (replace the placeholder with its full SHA):

```sh
for name in agent-instructions tool-selection clarify artifact; do gh skill install alexcatdad/skills "$name" --pin REVIEWED_COMMIT_SHA --dir "$HOME/.agents/skills"; done
gh skill install alexcatdad/skills codespace-sandbox --pin REVIEWED_COMMIT_SHA --dir "$HOME/.agents/skills"
chmod 755 "$HOME/.agents/skills/codespace-sandbox/scripts/run.sh"
```

`gh skill` currently writes script files without executable bits. The explicit
mode restoration above applies only to these reviewed scripts.

For an existing managed installation, use its skill migration process to
update source pins and preserve agent discovery configuration.

Review changes before explicitly installing a newer SHA. Roll back by installing
the previously reviewed SHA after preserving any local modifications. Avoid forced
overwrites of modified or independently owned packages. No startup updates run.

For a disposable local package check:

```sh
skill_fixture=$(mktemp -d)
for name in agent-instructions tool-selection clarify artifact; do gh skill install . "$name" --from-local --dir "$skill_fixture"; done
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
Linux and macOS. Artifact behavior inside agent clients and live Codespaces
provisioning require separate verification. The Codespaces tests use mocked CLI
responses and synthetic fixtures. Live execution requires separate Codespaces
permissions and a user-confirmed $0 Codespaces budget that stops usage at the limit; without that
confirmation the helper refuses creation. See [the skill](skills/codespace-sandbox/SKILL.md) for invocation
and cleanup recovery.

Keep changes scoped to reusable skills, retain package-relative paths and public
safe synthetic fixtures, and open a pull request with the relevant test results.
Do not add machine state, credentials, histories or agent session data.

## Releases

GitHub Actions publishes the next patch release after both CI jobs pass on
`main`. Each release has a `vMAJOR.MINOR.PATCH` tag for the validated commit.
Major and minor releases are versioned explicitly. Published tags stay fixed.
