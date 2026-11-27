# AGENTS.md

Guidance for humans and coding agents working in this repository. This file is human-owned.
Agents must not modify it.

## What this repository is

**agent-gate** is the Brightsmiths component that enforces which role may write where. It is a
Rust library plus a stateless CLI with three jobs:

- validate role policies;
- produce **mount plans** for sandbox-runner;
- run the commit-range **scope check** for gate-warden and sandbox-runner.

- System architecture: [brightsmiths/handbook](https://github.com/brightsmiths/handbook), under
  `docs/` (on `feat/initial` until merged).
- Specification: [`docs/spec/`](docs/spec/README.md).
- Architecture decisions: [`docs/adr/`](docs/adr/), using
  [`ADR_TEMPLATE.md`](docs/adr/ADR_TEMPLATE.md).
- Technology choices: [`.tech-decisions.yml`](.tech-decisions.yml).

## Rules

1. **This is a control-plane, security-boundary repository.** It is treated as T2+ whoever
   builds it. Every PR gets a human review.
2. **Read the spec first.** In particular:
   - [`docs/spec/constraints.md`](docs/spec/constraints.md);
   - [`docs/spec/security.md`](docs/spec/security.md);
   - [`docs/spec/requirements.md`](docs/spec/requirements.md).
3. **Never** add:
   - quality or test checks (formatting, linting, stubs, tests): those belong to commit-gate and
     gate-warden;
   - a pass/fail decision for a PR: agent-gate's result is one input to gate-warden;
   - discipline-specific logic: Rust conventions such as `*_tests.rs` come from the harness role
     definitions, never from code;
   - network access, a daemon, or any persistent state;
   - execution of repository content: no `git` subprocess, no hooks, no repository git config
     or attributes, no filters.
4. **Fail closed.** A policy, identity or git error is an `error` result, never a `pass`.
5. **Schema changes** to `schemas/` are cross-service interface changes. Follow the versioning
   rules in the interface specs and add an ADR.
6. **Committed files must not reference git-ignored scratch folders.** Cite the handbook
   instead.
7. **Never commit secrets.**

## Rust conventions

- **Tests:** sibling files `foo_tests.rs`, declared with
  `#[cfg(test)] #[path = "foo_tests.rs"] mod tests;`. Public-API tests go in `tests/`.
- **Errors:** expected errors are values (`Result`). No `unwrap` or `expect` on external data.
  No `unsafe`.
- **Formatting and linting:** `cargo fmt --check` and `cargo clippy -- -D warnings` must pass.
