# ADR-0002: Roles come from the harness; one classification rule; a protected floor

**Status:** Proposed
**Date:** 2026-11-27

## Context

The experiment hard-coded two modes, `tester` and `coder`, in `.agentgate.toml`. The factory
defines roles in the harness. The `oracle` and `builder` roles arrive at L1; `designer`,
`reviewer` and `health` come later. The harness owns cross-service schemas, including
`urn:brightsmiths:harness:roles:1`, which has these parts:

- `path_sets`: named globs, referenced as `@name`;
- per role: `zone`, `write`, `write_except`, `read_only` and `absent`.

The harness states part of the precedence: `write_except` beats `write`, and an explicit `write`
or `read_only` pattern beats `absent`. It does not say what happens when `write` and `read_only`
overlap without a `write_except`. The brief also requires the policy itself to be a protected
path that no agent can write.

## Decision

1. agent-gate **consumes** the harness roles schema. It does not define its own role format and
   knows no role names except the reserved `human` ([ADR-0004](ADR-0004-scope-check-semantics.md)).
2. **Discipline knowledge lives in the policy.** Path conventions such as `src/**/*_tests.rs`
   come from the pack's `roles.yaml`, never from code.
3. Each path is classified for a role as **W** (writable), **R** (read-only) or **A** (absent),
   in this order:
   1. **Protected floor:** a path under `.factory/` is never W for any agent role.
   2. **W** if it matches `write`, and matches neither `write_except` nor `read_only`.
   3. Otherwise **R** if it matches `write` or `read_only`. An explicit pattern beats `absent`.
   4. Otherwise **A** if it matches `absent`.
   5. Otherwise **R**. Unlisted paths are read as a snapshot.
4. **`read_only` beats `write`** when both match. A restriction always wins over a grant. This
   is agent-gate's reading of the harness schema, and the harness is asked to confirm it
   (assumption AS-05).
5. **Validation is strict and fails closed.** Each of these is a configuration error:
   - an unsupported schema major;
   - unknown fields;
   - an unresolved `@name`;
   - an invalid glob;
   - a role named `human`;
   - a zone outside `A`–`E`.

## Consequences

- New roles need only a harness change, with no agent-gate release.
- The floor cannot be relaxed by policy. The factory's own configuration (`pin.yaml`,
  `identities.yaml`, the repository-level `roles.yaml`, baselines) stays human-only.
- gate-warden's baseline writes under `.factory/baseline/` are not agent writes, so the floor
  does not affect them.

## Alternatives considered

- **agent-gate owns the role format:** conflicts with the harness owning cross-service schemas.
  Two formats would drift.
- **First match wins, by listing order:** order-sensitive policies are fragile to review.
- **Allow `write` to beat `read_only`:** a typo would then grant write access to locked tests.
- **A configurable protected floor:** the floor exists to survive a misconfigured policy, so it
  must not depend on that policy.
