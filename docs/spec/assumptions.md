# Assumptions

Each assumption was challenged and then resolved.

- **Decided** means the user confirmed it during spec planning, or it follows directly from the
  handbook.
- **Proposed – to be revisited** is a working default.
- **Open (cross-repo)** means another repository must act or confirm.

| ID | Assumption | Challenged because | Resolution | Impact / status |
| --- | --- | --- | --- | --- |
| AS-01 | agent-gate is a library plus a stateless CLI, not a networked service | "Service approach" could mean a daemon | The user chose library plus CLI. gate-warden must recompute in its own sandbox | Decided ([ADR-0001](../adr/ADR-0001-rust-library-and-stateless-cli.md)) |
| AS-02 | All experiment content is discarded | The experiment's hooks and agent files still have some value | The user stated the experiment can be discarded. Hook support returns as optional L2 | Decided ([ADR-0008](../adr/ADR-0008-boundaries-only.md)) |
| AS-03 | Roles come from the harness `roles:1` schema | agent-gate could own its format | The harness owns cross-service schemas (harness ADR-0002) | Decided ([ADR-0002](../adr/ADR-0002-roles-from-the-harness.md)) |
| AS-04 | Commits not made by a factory identity are violations; humans use an explicit `human` role | Treating unknown authors as human is friendlier | The user approved fail-closed with an explicit human role | Decided ([ADR-0004](../adr/ADR-0004-scope-check-semantics.md)) |
| AS-05 | `read_only` beats `write` when both match and no `write_except` applies | The harness schema states only `write_except` > `write` and explicit > `absent` | A restriction winning is the safe reading | **Open (cross-repo):** harness to confirm in `docs/specs/schemas.md#roles` |
| AS-06 | A glob without `/` matches only at the repository root | gitignore matches such patterns at any depth | The harness `factory` path set lists both `AGENTS.md` and `**/AGENTS.md`, which implies root-only | **Open (cross-repo):** harness to confirm the glob semantics |
| AS-07 | The protected floor is exactly `.factory/**` | `risk-map.yaml`, `AGENTS.md` and `.github/**` are also human-only | Those are R (not in any write set) for every role in the harness matrix, so they are already protected by default-deny. The floor covers only what must survive a broken policy | Proposed – to be revisited |
| AS-08 | The scope check emits gate-warden's `gate-result/v1` | The harness defines a different `gate-result:1` and claims ownership of the schema | gate-warden is the consumer and owns the emission contract. Emission sits behind a port | **Open (cross-repo):** the harness and gate-warden must agree on one format ([ADR-0005](../adr/ADR-0005-scope-check-emits-gate-result-v1.md)) |
| AS-09 | agent-gate owns the mount plan schema | The harness claims every cross-service schema | The harness has no mount plan schema. agent-gate defines it and offers it | **Open (cross-repo):** harness to adopt or confirm agent-gate ownership |
| AS-10 | The identity map lives at `.factory/identities.yaml` in each target repository, owned by agent-gate's schema | It could be org-wide deployment config, or part of the pin | Per repository is simple, human-owned and on the default branch (trusted in gate mode). Duplication across repositories is accepted at L1 | **Open (cross-repo):** harness (schema home) and gate-warden (configuration docs) |
| AS-11 | sandbox-runner stamps the role's App identity as author and committer on push, after a `--as-role` pre-check | The agent controls commit metadata inside the microVM | Without stamping, attribution is spoofable by the agent | **Open (cross-repo):** sandbox-runner spec |
| AS-12 | sandbox-runner can apply per-file ownership and modes in every provider (L2) | microVM providers differ in file system support | Required for [ADR-0007](../adr/ADR-0007-colocated-locked-files.md) | **Open (cross-repo):** sandbox-runner spec, L2 |
| AS-13 | gate-warden's workspace contains history from `GATE_BASE_SHA` to `GATE_HEAD_SHA` | Shallow fetches are common | gate-warden's sandbox integration already requires it | Decided (gate-warden spec). agent-gate fails closed otherwise |
| AS-14 | The stage contract's `outputs.writable_paths` narrows the mount plan, but not the scope check | The scope check could also narrow per stage | The scope check runs per role identity. Stage-level narrowing in gate-warden would need the stage contract, which gate-warden does not have | Proposed – to be revisited at L3 |
| AS-15 | agent-gate reads `.factory/pin.yaml` only for `discipline` | The harness lists agent-gate as a pin consumer | That is enough to locate `roles.yaml` in gate mode | Decided |
| AS-16 | Rename detection is off | Rename-aware findings would be friendlier | Both sides must be checked anyway. Heuristics add nondeterminism | Decided |
| AS-17 | Performance targets as in [operations.md](operations.md) | No load data | Measure on the M1 pilot (commit-gate) | Proposed – to be revisited after M1 |
| AS-18 | Push ruleset generation and signature verification come after the factory role is complete | The brief lists push rulesets as optional | Not in the L1 or L2 increments | Decided |
| AS-19 | No CODEOWNERS file is committed yet | The repository is T2+ and needs human review | The owning team is not yet defined | Proposed: add once the maintainers team exists. Until then, use a ruleset requiring one approval |
