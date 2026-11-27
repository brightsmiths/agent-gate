# Behavioural assertions

These are testable Given/When/Then statements. Each one names the requirements it covers
([requirements.md](requirements.md)). L1 assertions are binding for the M1 build. L2 assertions
are outlines.

Unless stated otherwise, **"the L1 policy"** is the harness illustrative software-pack
`roles.yaml` ([interfaces/roles-input.md](interfaces/roles-input.md)). **"The identity map"**
maps `oracle-bot@x` to `oracle`, `builder-bot@x` to `builder` and `alice@x` to `human`, and has
the pass-through committer `noreply@github.com`.

## L1: Policy and classification

### 1. Builder classification

- **Given** the L1 policy
- **When** paths are classified for `builder`
- **Then**:
  - `src/lib.rs` is W;
  - `src/a/b_tests.rs` is R;
  - `tests/own/main.rs` is W;
  - `tests/api.rs` is R;
  - `tests/fixtures/x.json` is R;
  - `Cargo.toml` is W;
  - `spec/intent.md` is R;
  - `README.md` is R (default).
- *Covers:* AG-REQ-003, AG-REQ-004

### 2. Oracle classification

- **Given** the L1 policy
- **When** paths are classified for `oracle`
- **Then**:
  - `src/lib.rs` is A;
  - `src/lib_tests.rs` is W (an explicit `write` beats `absent`);
  - `tests/own/x.rs` is A;
  - `tests/locked/MANIFEST` is W;
  - `Cargo.toml` is R.
- *Covers:* AG-REQ-004

### 3. `read_only` beats `write`

- **Given** a role with `write: ["src/**"]` and `read_only: ["src/gen/**"]`, and no
  `write_except`
- **When** `src/gen/a.rs` is classified
- **Then** it is R.
- *Covers:* AG-REQ-004

### 4. Protected floor holds against the policy

- **Given** a role with `write: ["**"]`
- **When** `.factory/pin.yaml` is classified
- **Then** it is R.
- *Covers:* AG-REQ-005

### 5. Strict validation

- **Given** a roles document with a role field `writes` (a typo)
- **When** it is loaded
- **Then** loading fails with `PolicyInvalid` naming `writes`
- **And** no plan or pass result is produced.
- *Covers:* AG-REQ-002, AG-REQ-049

### 6. Reserved `human`

- **Given** a roles document defining a role `human`
- **When** it is loaded
- **Then** it fails with `PolicyInvalid`.
- *Covers:* AG-REQ-002

### 7. Unsupported major

- **Given** `schema: urn:brightsmiths:harness:roles:2`
- **When** it is loaded
- **Then** it fails with `SchemaMajorUnsupported`.
- *Covers:* AG-REQ-001

## L1: Mount plan

### 8. Oracle plan over a Rust checkout

- **Given** a checkout containing `Cargo.toml`, `src/lib.rs`, `src/lib_tests.rs`,
  `tests/api.rs` and `tests/own/main.rs`
- **When** `mount-plan --role oracle` runs
- **Then** the entries are, in this order:
  - `""` rw;
  - `Cargo.toml` ro;
  - `src` rw;
  - `src/lib.rs` absent;
  - `src/lib_tests.rs` rw;
  - `tests` rw;
  - `tests/api.rs` rw;
  - `tests/own` absent.
- **And** there is no entry below `tests/own`.
- *Covers:* AG-REQ-020, 021, 022

### 9. Narrowing never widens

- **Given** `builder` with `--writable-paths src/billing/** docs/**`
- **When** the plan is produced
- **Then** `src/billing/a.rs` is rw, `src/lib.rs` is ro, and `docs/x.md` is ro.
- *Covers:* AG-REQ-024

### 10. Human is not plannable

- **Given** `--role human`
- **When** `mount-plan` runs
- **Then** it exits `2` and writes no plan.
- *Covers:* AG-REQ-025

### 11. Symlinks are not followed

- **Given** a checkout containing a symlink `src/link -> /etc`
- **When** the plan is produced
- **Then** `src/link` appears once with kind `symlink`, and nothing under `/etc` is read.
- *Covers:* AG-REQ-023

### 12. Deterministic plan

- **Given** the same checkout created in two different file creation orders
- **When** plans are produced
- **Then** they are byte-identical.
- *Covers:* AG-REQ-006

## L1: Scope check

### 13. Clean builder range passes

- **Given** two commits by `builder-bot@x` touching `src/lib.rs` and `tests/own/main.rs`
- **When** `scope-check` runs
- **Then** the status is `pass`, the exit code is `0`, and `scope.commits = 2`.
- *Covers:* AG-REQ-040, 044, 048

### 14. Builder edits a locked test

- **Given** a commit by `builder-bot@x` modifying `src/lib_tests.rs`
- **When** `scope-check` runs
- **Then** the status is `fail`, the exit code is `1`, and there is one finding with rule
  `out-of-scope` and path `src/lib_tests.rs`.
- *Covers:* AG-REQ-044, 048

### 15. Rename checks both sides

- **Given** a builder commit renaming `tests/api.rs` to `src/api.rs`
- **Then** there is a finding `out-of-scope` on `tests/api.rs` and no finding on `src/api.rs`.
- *Covers:* AG-REQ-041

### 16. Unknown identity

- **Given** a commit authored by `mallory@x`, who is not in the map
- **Then** there is one finding `unknown-identity` with no path, and its path changes are not
  evaluated.
- *Covers:* AG-REQ-043

### 17. Mixed identity

- **Given** a commit authored by `oracle-bot@x` and committed by `builder-bot@x`
- **Then** there is a finding `mixed-identity`.
- *Covers:* AG-REQ-043

### 18. Pass-through committer

- **Given** a commit authored by `alice@x` and committed by `noreply@github.com`, touching
  `src/lib_tests.rs`
- **Then** there are no findings (human role).
- *Covers:* AG-REQ-043, 045

### 19. Human merge of the default branch

- **Given** a merge commit by `alice@x` that merges the default branch without conflicts, where
  the default-branch side changed `src/lib_tests.rs`
- **Then** the merge commit reports no changed paths.
- *Covers:* AG-REQ-042

### 20. Evil merge by an agent

- **Given** a merge commit by `builder-bot@x` whose tree differs from both parents at
  `tests/api.rs`
- **Then** there is a finding `out-of-scope` on `tests/api.rs`.
- *Covers:* AG-REQ-042

### 21. Symlink by an agent

- **Given** a builder commit adding the symlink `src/t` → `../tests/api.rs`
- **Then** there is a finding `special-entry` on `src/t`.
- *Covers:* AG-REQ-046

### 22. Protected path

- **Given** an oracle commit adding `.factory/identities.yaml`
- **Then** there is a finding `protected-path`.
- *Covers:* AG-REQ-044

### 23. All violations reported in order

- **Given** three commits, each with two violations
- **Then** there are six findings, ordered by commit (oldest first), then path, then rule.
- *Covers:* AG-REQ-047

### 24. Findings cap

- **Given** 1500 violations
- **Then** there are exactly 1000 findings, `scope.violations = 1500`, the summary states the
  total, and the document is at most 1 MiB.
- *Covers:* AG-REQ-048, 062

### 25. Incomplete history fails closed

- **Given** a shallow repository in which `base` is missing
- **Then** the status is `error`, the exit code is `2`, and the summary names `HistoryIncomplete`.
- *Covers:* AG-REQ-049

### 26. Empty range

- **Given** `base == head`
- **Then** the status is `pass` and `scope.commits = 0`.
- *Covers:* AG-REQ-040

### 27. Pre-push mode

- **Given** `--as-role builder` and a commit authored by `whoever@local` modifying
  `src/lib_tests.rs`
- **Then** there is a finding `out-of-scope`, and no identity findings.
- *Covers:* AG-REQ-050

## L1: gate-warden mode

### 28. Inputs from trusted trees

- **Given** `GATE_*` variables set, a default-branch pin with `discipline: software`, and a PR
  head that changes `.factory/identities.yaml` to map `builder-bot@x` to `human`
- **When** `agent-gate scope-check` runs with no arguments
- **Then** the identity map comes from `GATE_DEFAULT_BRANCH_DIR`, so the builder stays `builder`
- **And** the PR's edit is a `protected-path` finding.
- *Covers:* AG-REQ-060, AG-REQ-005

### 29. Policy inside the workspace refused

- **Given** gate-warden mode and `--roles $GATE_WORKSPACE/roles.yaml`
- **Then** the status is `error` (`UntrustedPolicyLocation`).
- *Covers:* AG-REQ-061

### 30. Repository content never executed

- **Given** a repository with a `.gitattributes` filter driver and `.git/hooks/post-checkout`
  that would create a marker file
- **When** `scope-check` runs
- **Then** no marker file exists afterwards.
- *Covers:* AG-REQ-070

## L2 (outline)

### 31. Locked file attributes

- **Given** `builder` and a checkout with `src/lib_tests.rs`
- **Then** that entry has `owner: locked`, `mode: "0444"`, and `src` has `owner: locked`,
  `mode: "1775"`, `sticky: true`.
- *Covers:* AG-REQ-100

### 32. Repository roles replace the pack

- **Given** `$GATE_DEFAULT_BRANCH_DIR/.factory/roles.yaml` defining `harness-author`
- **Then** `harness-author` is available, the pack's `builder` is not, and the output records
  `source: repository`.
- *Covers:* AG-REQ-101
