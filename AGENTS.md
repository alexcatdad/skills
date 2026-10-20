# Skills repository

This repository owns reusable personal skill implementations. Keep global agent
instructions, installation policy, source pins and discovery configuration in
`alexcatdad/dotfiles`; keep project-specific skills in their owning repositories.

- Preserve each complete package under `skills/<name>/`, with package-relative
  paths and executable script permissions.
- Keep changes small and public-safe. Use synthetic fixtures; exclude credentials,
  machine configuration, histories and session data.
- Run `sh tests/check.sh` after package or test changes. When available, also run
  `gh skill publish --dry-run` to validate GitHub skill packaging.
- Report behavioral checks separately from actual execution in an agent client
  or live service connectivity.
