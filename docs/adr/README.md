# Architecture decision records

ADRs follow the handbook template ([ADR_TEMPLATE.md](ADR_TEMPLATE.md)). Only humans change an
ADR's status to `Accepted`.

| ADR | Decision | Level |
| --- | --- | --- |
| [ADR-0001](ADR-0001-rust-library-and-stateless-cli.md) | Rust library plus stateless CLI; no daemon | L1 |
| [ADR-0002](ADR-0002-roles-from-the-harness.md) | Roles come from the harness; classification precedence; protected floor | L1 |
| [ADR-0003](ADR-0003-mount-plan-format.md) | Mount plan: enumerated, provider-neutral, versioned JSON | L1 |
| [ADR-0004](ADR-0004-scope-check-semantics.md) | Scope check: per-commit attribution, identity map, explicit `human` role | L1 |
| [ADR-0005](ADR-0005-scope-check-emits-gate-result-v1.md) | Scope check emits gate-warden's `gate-result/v1` | L1 |
| [ADR-0006](ADR-0006-trusted-inputs-and-safe-git-reading.md) | Trusted inputs only from trusted trees; git read through a library | L1 |
| [ADR-0007](ADR-0007-colocated-locked-files.md) | Colocated locked files: other owner, `0444`, sticky `1775` directories | L2 |
| [ADR-0008](ADR-0008-boundaries-only.md) | Boundaries only; agent hooks are optional and not the enforcement path | L1/L2 |
| [ADR-0009](ADR-0009-repository-level-roles-file.md) | Repository-level `.factory/roles.yaml` replaces the pack roles | L2 |
