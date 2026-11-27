# agent-gate

agent-gate enforces **which role may write where**, from a single policy. It is part of the
Brightsmiths factory, the system that takes engineering work from a GitHub issue to a merged PR
and a published release.

The same policy drives:

1. **Mount plans.** For a role and a checkout, agent-gate emits a machine-readable plan that
   sandbox-runner applies to the agent's microVM: each path is read-write, read-only or absent.
2. **The commit-range scope check.** For `base..head`, agent-gate checks that every path changed by
   every commit is writable by the role of the identity that authored the commit. gate-warden runs
   it authoritatively. sandbox-runner runs it before pushing.

agent-gate is a Rust **library plus a stateless CLI**. It has no daemon, no network access and no
state. Its scope-check result is **one input** to gate-warden. It never decides pass or fail for
a PR on its own authority. It runs no quality checks (formatting, linting, tests). Those belong
to commit-gate and gate-warden.

## Status

Specification phase. Nothing is implemented yet.

- Specification: [`docs/spec/`](docs/spec/README.md)
- Architecture decisions: [`docs/adr/`](docs/adr/README.md)
- Technology choices: [`.tech-decisions.yml`](.tech-decisions.yml)
- System architecture: [brightsmiths/handbook](https://github.com/brightsmiths/handbook), under
  `docs/` (on the `feat/initial` branch until merged)

The earlier soft-enforcement experiment (tester/coder modes, Claude Code hooks, a git pre-commit
hook and shell scripts) has been removed. Its idea of one policy with several enforcement layers is
kept. The fixed modes are replaced with roles that the harness defines.

## License

See [LICENSE](LICENSE).
