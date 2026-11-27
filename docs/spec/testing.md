# Testing

## Layers

| Layer | Scope | Tooling |
| --- | --- | --- |
| Unit | Glob compiler, classifier, policy validation, identity resolver, scope evaluator, mount planner, report mapper. Pure functions with in-memory fakes of the ports | sibling `*_tests.rs`, cargo-nextest |
| Property | See the properties below | proptest |
| Contract | Outputs validate against `schemas/mount-plan/v1.schema.json` and gate-warden's `schemas/gate-result/v1.schema.json` (vendored by `$id`). The harness illustrative `roles.yaml` files load | JSON Schema validator in tests |
| Integration (git) | Real repositories built in temporary directories by a fixture builder. Covers renames, merges, octopus merges, symlinks, gitlinks, mode changes, shallow clones and non-UTF-8 paths | `tests/` (public API) |
| CLI | End-to-end invocations, including gate-warden mode with a simulated `GATE_*` environment and trusted trees | `tests/` with a test binary harness |
| Red-team | The scenarios in [security.md](security.md#red-team-scenarios-test-suite) | `tests/` |
| Fuzz | Roles YAML, identity YAML and glob parsing never panic and always end in `Ok` or `PolicyInvalid` | cargo-fuzz (CI smoke run) |
| Mutation | Business-logic crate | cargo-mutants |

## Properties

1. **Plan and check agree:** for any policy, role and path, the plan's access for an existing
   file equals `classify`. A file the scope check accepts as changed by role R is exactly a file
   with W access in R's unnarrowed plan.
2. **Narrowing is monotone:** adding narrowing globs never turns an `ro` or `absent` path into
   `rw`.
3. **The floor holds:** for any policy and agent role, `.factory/**` is never W.
4. **Determinism:** shuffling the checkout enumeration order or the commit iteration order
   (within the topological order) does not change the output bytes.
5. **Fail closed:** for any injected port error, the status is `error` and the exit code is `2`.
6. **Cap invariants:** findings ≤ 1000; document ≤ 1 MiB; `scope.violations` is the true count.

## Fixtures

- `fixtures/policies/`:
  - the harness L1 software `roles.yaml`;
  - the harness `.factory/roles.yaml` example (L2);
  - one invalid policy per validation rule.
- A git fixture builder: a small DSL to create commits with chosen author, committer, parents,
  entries and modes. No `git` subprocess in tests either, to keep the same reader under test.
- Checkout fixtures for mount plans, including symlinks and deep trees.

## Targets (proposed)

- Business-logic crate: ≥ 95% line coverage and ≥ 85% mutation score.
- Every L1 assertion in [assertions.md](assertions.md) maps to at least one named test.
- CI runs unit, property, contract, integration, CLI and red-team tests on every PR, a 60-second
  fuzz smoke, and mutation on changed files.

## Test doubles

- Business-logic tests use in-memory fakes for every port. No mocks of the classifier: it is
  pure and always used for real.
- Adapters are tested against real file systems and real repositories in temporary directories.
