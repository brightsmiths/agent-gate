# agent-gate specification

agent-gate enforces **which role may write where**, from one policy. The policy is the harness
role definitions, which include the pack's path conventions. From that policy agent-gate:

- produces the **mount plan** sandbox-runner applies to each agent microVM;
- runs the **commit-range scope check**: gate-warden runs it authoritatively, and sandbox-runner
  runs it before pushing.

agent-gate is a Rust library plus a stateless CLI. Its result is one input to gate-warden. It
never decides pass or fail for a PR, and it runs no quality or test checks.

The system-level architecture lives in the handbook:
[brightsmiths/handbook](https://github.com/brightsmiths/handbook), under `docs/`. Until it is
merged to `main`, it is on the `feat/initial` branch. The pages that matter most here are:

- `docs/architecture/agent-profiles.md`: trust zones and the visibility and write matrix
- `docs/architecture/isolation-and-security.md`: enforcement layers for path ownership
- `docs/architecture/oracles.md`: locked tests and colocated locked files
- `docs/architecture/services.md`: the agent-gate, sandbox-runner and gate-warden entries
- `docs/roadmap.md`: agent-gate L1 (M1) and L2 (M2)

Sibling specifications:

- [brightsmiths/harness](https://github.com/brightsmiths/harness) `docs/specs/roles-and-paths.md`
  and `docs/specs/schemas.md`: the roles schema agent-gate consumes.
- [brightsmiths/gate-warden](https://github.com/brightsmiths/gate-warden)
  `docs/spec/interfaces/gate-result-format.md`: the result format agent-gate emits.

## The story in one paragraph

CogWorks picks a profile for a stage. Its stage contract names an identity role, such as
`builder`. Before booting the microVM, sandbox-runner asks agent-gate for a **mount plan** for
that role over the prepared checkout. Each path is read-write, read-only or absent, following
the harness `roles.yaml`. The agent works and commits. Before pushing, sandbox-runner runs
`scope-check --as-role builder` over the new commits, stamps the builder App's identity on them,
and pushes. gate-warden then runs `scope-check` over `merge-base..head` in its clean sandbox.
It reads the policy and identity map only from the pinned harness and the default branch. It
attributes each commit to a role through the identity map and writes a `gate-result/v1`
document. Any out-of-scope path fails the check, and the gate with it.

## Levels

| Level | Milestone | Content |
| --- | --- | --- |
| **L1** | M1 (human-led) | Harness-defined roles (`oracle`, `builder`); policy validation; `mount-plan`; `scope-check` with an identity map and an explicit `human` role; gate-warden mode; Rust library plus CLI |
| L2 (planned) | M2 (factory-built) | Ownership, mode and sticky-directory plans for colocated locked files; repository-level `.factory/roles.yaml`; optional `check-path` and hook output for human-led use; boundaries only |
| After factory role complete | — | Push ruleset generation; commit signature verification |

## Documents

Suggested reading order:

| File | Purpose |
| --- | --- |
| [overview.md](overview.md) | System context, consumers, scope per level, non-goals |
| [vocabulary.md](vocabulary.md) | Domain concepts and error concepts |
| [requirements.md](requirements.md) | AG-REQ requirements (EARS), with acceptance criteria for L1 |
| [interfaces/roles-input.md](interfaces/roles-input.md) | How agent-gate reads the harness roles schema; classification rules; glob semantics |
| [interfaces/identity-map.md](interfaces/identity-map.md) | Identity map `urn:brightsmiths:agent-gate:identities:1` |
| [interfaces/mount-plan.md](interfaces/mount-plan.md) | Mount plan `urn:brightsmiths:agent-gate:mount-plan:1` |
| [interfaces/scope-check-result.md](interfaces/scope-check-result.md) | Scope-check output in `gate-result/v1` |
| [interfaces/cli.md](interfaces/cli.md) | Commands, arguments, environment, exit codes |
| [architecture.md](architecture.md) | Business logic, ports, adapters; main flows |
| [responsibilities.md](responsibilities.md) | CRC cards per component |
| [security.md](security.md) | Threat model |
| [assertions.md](assertions.md) | Given/When/Then behavioural assertions |
| [edge-cases.md](edge-cases.md) | Unusual flows and failure modes |
| [testing.md](testing.md) | Test layers, fixtures, targets |
| [operations.md](operations.md) | Distribution, versioning, use by consumers |
| [constraints.md](constraints.md) | Rules for implementers: types, errors, boundaries, performance |
| [tradeoffs.md](tradeoffs.md) | Alternatives considered |
| [assumptions.md](assumptions.md) | Challenged assumptions, open cross-repo items |

Machine-readable schemas:

- [`schemas/mount-plan/v1.schema.json`](../../schemas/mount-plan/v1.schema.json)
- [`schemas/identities/v1.schema.json`](../../schemas/identities/v1.schema.json)

## Architecture decisions

See [`docs/adr/`](../adr/README.md). In short:

1. Rust library plus stateless CLI; no daemon, no network
   ([ADR-0001](../adr/ADR-0001-rust-library-and-stateless-cli.md)).
2. Roles come from the harness; one classification rule; a `.factory/**` floor
   ([ADR-0002](../adr/ADR-0002-roles-from-the-harness.md)).
3. An enumerated, provider-neutral mount plan ([ADR-0003](../adr/ADR-0003-mount-plan-format.md)).
4. Per-commit attribution through an identity map; explicit `human` role
   ([ADR-0004](../adr/ADR-0004-scope-check-semantics.md)).
5. The scope check emits `gate-result/v1`
   ([ADR-0005](../adr/ADR-0005-scope-check-emits-gate-result-v1.md)).
6. Trusted inputs only from trusted trees; git read through a library
   ([ADR-0006](../adr/ADR-0006-trusted-inputs-and-safe-git-reading.md)).
7. *(L2)* Colocated locked files by ownership and sticky directories
   ([ADR-0007](../adr/ADR-0007-colocated-locked-files.md)).
8. Boundaries only; hooks optional ([ADR-0008](../adr/ADR-0008-boundaries-only.md)).
9. *(L2)* A repository-level roles file replaces the pack roles
   ([ADR-0009](../adr/ADR-0009-repository-level-roles-file.md)).

## Open items

Cross-repository items are listed in [assumptions.md](assumptions.md):

- AS-05: harness confirmation that `read_only` beats `write`.
- AS-08: the gate result format conflict between the harness and gate-warden.
- AS-09 and AS-10: whether the harness adopts the mount plan and identity map schemas.
- AS-11: sandbox-runner must stamp role identity on push.
- AS-12: sandbox-runner must support per-file ownership (L2).
- AS-13: gate-warden must fetch history down to the merge base.

## Workflow for the interface designer

1. **Start from the business logic** in [architecture.md](architecture.md) and the concepts in
   [vocabulary.md](vocabulary.md). Turn them into Rust types, respecting
   [constraints.md](constraints.md):
   - newtypes for `RoleName`, `RepoPath`, `Glob` and `CommitId`;
   - closed enums for `Access`, `ViolationRule` and `CheckStatus`;
   - `Result`-based errors.
2. **Define the ports** (PolicySource, IdentitySource, CheckoutReader, CommitRangeReader,
   ResultSink, Environment) as traits.
3. **Derive Rust types from the schemas** and add contract tests against them. That covers the
   harness roles schema, `schemas/*`, and gate-warden's `gate-result/v1`.
4. **Lay out workspace crates** so the dependency rule is mechanically enforced.
5. **Map each L1 assertion** in [assertions.md](assertions.md) to a test location.
6. **Report spec gaps back.** Edit [edge-cases.md](edge-cases.md),
   [assertions.md](assertions.md) or [vocabulary.md](vocabulary.md), or add a
   `clarifications.md`.
