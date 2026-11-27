# Requirements

Requirements use EARS form and are numbered `AG-REQ-NNN`. Each has a level tag:

- **[L1]** is in scope for the M1 build and has acceptance criteria (AC).
- **[L2] (planned)** items are specified enough to plan. They are refined when L2 starts.
- **[After factory role complete]** items are kept on the roadmap but are not built for the
  factory.

Terms are defined in [vocabulary.md](vocabulary.md). Gaps are recorded in
[assumptions.md](assumptions.md). Numbering leaves gaps on purpose.

---

## L1: Policy

### AG-REQ-001 [L1] Load harness roles

agent-gate shall load a roles document conforming to `urn:brightsmiths:harness:roles:1` from a
YAML file.

- **AC1:** the illustrative software-pack `roles.yaml` from the harness spec loads without error.
- **AC2:** a document whose `schema` names major `2` fails with `SchemaMajorUnsupported`.

### AG-REQ-002 [L1] Strict validation

If a roles document contains any of the following, agent-gate shall reject it with
`PolicyInvalid` and shall not produce a plan or a pass:

- an unknown field or a duplicate key;
- an unresolved `@name` or a nested `@name` inside a path set;
- an invalid glob (leading `/`, a `..` segment, `!` negation, empty);
- a zone outside `A`–`E`;
- a duplicate role, or a role named `human`.

- **AC1:** one fixture per listed defect, and each is rejected with a message naming the
  offending field.

### AG-REQ-003 [L1] Glob semantics

agent-gate shall match globs as specified in
[interfaces/roles-input.md](interfaces/roles-input.md#glob-semantics): repository-relative,
case-sensitive, `*` not crossing `/`, and `**` matching zero or more whole segments.

- **AC1:** `src/**/*_tests.rs` matches `src/a_tests.rs` and `src/x/y/a_tests.rs`. It does not
  match `src/a_tests.rs.bak` or `SRC/a_tests.rs`.
- **AC2:** `tests/*.rs` matches `tests/api.rs` and not `tests/own/main.rs`.

### AG-REQ-004 [L1] Classification

agent-gate shall classify each (agent role, path) pair as W, R or A using the precedence in
[ADR-0002](../adr/ADR-0002-roles-from-the-harness.md):

1. protected floor;
2. W if `write` matches, and neither `write_except` nor `read_only` matches;
3. R if `write` or `read_only` matches;
4. A if `absent` matches;
5. R otherwise.

- **AC1:** with the harness L1 policy, `builder` gives W for `src/lib.rs`, R for
  `src/lib_tests.rs`, W for `tests/own/main.rs`, R for `tests/api.rs` and R for `spec/x.md`.
- **AC2:** `oracle` gives A for `src/lib.rs`, W for `src/lib_tests.rs` and A for
  `tests/own/main.rs`.
- **AC3:** a path matching both `write` and `read_only`, with no `write_except`, is R.

### AG-REQ-005 [L1] Protected floor

agent-gate shall never classify a path matching `.factory/**` as W for an agent role, whatever
the policy says.

- **AC1:** a policy granting `write: ["**"]` still gives R for `.factory/identities.yaml`.

### AG-REQ-006 [L1] Deterministic output

agent-gate shall produce byte-identical output for identical inputs, independent of file system
enumeration order, locale, time zone and host OS.

- **AC1:** running the same invocation twice, and on a checkout copied in a different order,
  gives identical bytes.

### AG-REQ-007 [L1] Validate command

When invoked as `agent-gate validate --roles <file> [--identities <file>]`, agent-gate shall
validate the documents and exit `0` if they are valid, or `2` with diagnostics if they are not.

- **AC1:** harness CI can run it on every `roles.yaml` in the pack.

---

## L1: Mount plan

### AG-REQ-020 [L1] Produce a mount plan

When invoked as `agent-gate mount-plan --roles <file> --role <role> --checkout <dir>`, agent-gate
shall emit a `urn:brightsmiths:agent-gate:mount-plan:1` document to stdout or `--output`.

- **AC1:** the output validates against `schemas/mount-plan/v1.schema.json`.

### AG-REQ-021 [L1] Enumerate every entry

The mount plan shall contain one entry for every file, directory and symlink in the checkout,
except `.git/` and anything below an `absent` directory. Each entry shall carry its kind and
access.

- **AC1:** for a fixture checkout, the set of entry paths equals the set of non-`.git` paths,
  minus descendants of absent directories.

### AG-REQ-022 [L1] Directory access

agent-gate shall set a directory's access to:

- `rw` if the role may create at least one new path inside it, given its rules and any narrowing;
- otherwise `absent` if every existing descendant is `absent` and no new path inside it could be
  W or R;
- otherwise `ro`.

- **AC1:** for `oracle` with the harness L1 policy, `src/` is `rw` (because `*_tests.rs` may be
  created), `src/lib.rs` is `absent` and `src/lib_tests.rs` is `rw`.
- **AC2:** for `builder`, `tests/fixtures/` is `ro`.

### AG-REQ-023 [L1] Symlinks are not followed

agent-gate shall list a symlink in the checkout as kind `symlink`, classified by its own path,
and shall never follow it.

- **AC1:** a symlink `src/x -> ../../etc` produces exactly one entry, and nothing outside the
  checkout is read.

### AG-REQ-024 [L1] Narrowing never widens

Where `--writable-paths <glob>...` is given, agent-gate shall make a path W only if it is W for
the role **and** matches at least one narrowing glob. Paths that are W for the role but outside
the narrowing shall become R.

- **AC1:** narrowing `builder` to `src/billing/**` makes `src/lib.rs` R.
- **AC2:** a narrowing glob outside the role's write set grants nothing.

### AG-REQ-025 [L1] Refuse unplannable roles

If `--role` is `human` or is not in the policy, agent-gate shall exit `2` without emitting a plan.

### AG-REQ-026 [L1] Plan provenance

The plan shall record the role, the zone, the expanded rules (including narrowing), the policy
source and the
policy digest.

---

## L1: Scope check

### AG-REQ-040 [L1] Evaluate a commit range

When invoked as `agent-gate scope-check --roles <file> --identities <file> --range <base>..<head>
[--repo <dir>]`, agent-gate shall evaluate every commit reachable from `head` and not from `base`.

- **AC1:** a range with three commits reports `scope.commits = 3`.
- **AC2:** `base == head` gives `pass` with zero commits.

### AG-REQ-041 [L1] Changed paths

For a non-merge commit, agent-gate shall treat as changed every path that was added, deleted,
modified in content or mode, or renamed. For a rename, both the old and the new path count as
changed.

- **AC1:** renaming `tests/api.rs` to `src/api.rs` by `builder` gives an `out-of-scope` violation
  on `tests/api.rs`.

### AG-REQ-042 [L1] Merge commits

For a merge commit, agent-gate shall treat as changed only the paths whose entry differs from
**every** parent.

- **AC1:** a human merge of the default branch with no conflict resolution reports no changed
  paths for the merge commit.
- **AC2:** an agent-role merge commit that also edits `tests/api.rs` reports that path.

### AG-REQ-043 [L1] Resolve identity

agent-gate shall resolve each commit's role from its author email through the identity map.

- If the author is not mapped, the commit shall get one `unknown-identity` violation.
- If the committer is neither mapped to the same role nor a pass-through committer, the commit
  shall get one `mixed-identity` violation.

- **AC1:** an author `oracle-bot` with committer `builder-bot` gives `mixed-identity`.
- **AC2:** a human author with committer `noreply@github.com` (listed as pass-through) gives no
  identity violation.

### AG-REQ-044 [L1] Agent-role path check

For each commit whose role is an agent role, agent-gate shall report:

- `protected-path` for each changed path under the protected floor;
- `out-of-scope` for each other changed path that is not W for that role.

- **AC1:** `builder` modifying `src/lib_tests.rs` gives `out-of-scope`.
- **AC2:** `oracle` adding `.factory/identities.yaml` gives `protected-path`.

### AG-REQ-045 [L1] Human role

For each commit whose role is `human`, agent-gate shall report no path violations.

### AG-REQ-046 [L1] Special entries and invalid paths

For agent-role commits, agent-gate shall report:

- `special-entry` for each added or modified symlink or gitlink;
- `invalid-path` for each changed path that is not valid UTF-8 or contains a control character.

- **AC1:** `builder` adding the symlink `src/t -> ../tests/api.rs` gives `special-entry`, even
  though `src/t` is W.

### AG-REQ-047 [L1] Report all violations

agent-gate shall report every violation in the range. The order shall be commit topological
order (oldest first, ties broken by commit ID), then path bytes, then rule.

### AG-REQ-048 [L1] Gate result

agent-gate shall emit the result as gate-warden `gate-result/v1`, as specified in
[interfaces/scope-check-result.md](interfaces/scope-check-result.md). Exit codes are `0` for pass,
`1` for fail and `2` for error.

- **AC1:** the output validates against gate-warden's `schemas/gate-result/v1.schema.json`.
- **AC2:** 1500 violations produce exactly 1000 findings, and `scope.violations = 1500`.

### AG-REQ-049 [L1] Fail closed

If any error occurs (policy, identity map, range, history, limits, I/O), agent-gate shall emit
status `error` where a result destination is available, and shall exit `2`. It shall never emit
`pass` after an error.

- **AC1:** a shallow repository missing `base` gives `error` (`HistoryIncomplete`).

### AG-REQ-050 [L1] Pre-push mode

When invoked with `--as-role <role>` instead of `--identities`, agent-gate shall attribute every
commit in the range to that agent role and skip identity resolution.

- **AC1:** sandbox-runner can run the check before it re-stamps identities.
- **AC2:** `--as-role human` is rejected with exit `2`.

---

## L1: gate-warden mode

### AG-REQ-060 [L1] Inputs from the gate environment

When `GATE_RESULT_FILE` is set and an argument is omitted, agent-gate shall take:

- the range from `GATE_BASE_SHA..GATE_HEAD_SHA`;
- the repository from `GATE_WORKSPACE`;
- the check ID from `GATE_CHECK_ID`;
- the policy from `$GATE_HARNESS_DIR/disciplines/<discipline>/roles.yaml`, where `<discipline>`
  comes from `$GATE_DEFAULT_BRANCH_DIR/.factory/pin.yaml`;
- the identity map from `$GATE_DEFAULT_BRANCH_DIR/.factory/identities.yaml`.

It shall write the result to `GATE_RESULT_FILE`.

- **AC1:** `agent-gate scope-check` with no arguments works under gate-warden's emission
  contract.

### AG-REQ-061 [L1] Refuse untrusted policy locations

While in gate-warden mode, if a roles or identity file path resolves (after canonicalisation)
inside `GATE_WORKSPACE`, agent-gate shall fail with `UntrustedPolicyLocation`.

- **AC1:** `--identities $GATE_WORKSPACE/.factory/identities.yaml` gives `error`.

### AG-REQ-062 [L1] Result size

agent-gate shall keep the result document within 1 MiB. It shall truncate finding messages and
cap the number of findings before it would exceed that size.

---

## L1: Safety and packaging

### AG-REQ-070 [L1] Never execute repository content

agent-gate shall read git history through a library. It shall never:

- spawn `git` or any other process;
- apply repository config, attributes, filters or hooks;
- read file contents during the scope check.

- **AC1:** a repository with a malicious `.gitattributes` filter and `core.fsmonitor` config is
  checked without either taking effect.

### AG-REQ-071 [L1] No network

agent-gate shall not open network connections.

### AG-REQ-072 [L1] Resource limits

agent-gate shall enforce configurable limits, with defaults, on:

- commits per range (default 10,000);
- changed paths per range (default 1,000,000);
- checkout entries (default 1,000,000);
- policy and identity file sizes (default 1 MiB each).

If a limit is exceeded, it shall fail with `LimitExceeded`.

### AG-REQ-073 [L1] Library API

agent-gate shall expose validate, classify, mount-plan and scope-check as a Rust library API.
The CLI shall be a thin adapter over it.

- **AC1:** the business-logic crate has no file system, git, serialisation or CLI dependencies
  (cargo-deny check).

### AG-REQ-074 [L1] Usage documentation

The repository shall document each command, its inputs, outputs and exit codes, and how
sandbox-runner and gate-warden invoke it.

---

## L2 (planned)

### AG-REQ-100 [L2] Ownership for colocated locked files

Mount plan entries shall carry an owner class (`agent`, `locked`), a mode and a sticky flag, as
in [ADR-0007](../adr/ADR-0007-colocated-locked-files.md):

- locked files: `locked`, `0444`;
- `rw` directories containing locked files: `locked`, `1775` with the sticky bit;
- agent-writable files: `agent`.

- **AC1 (outline):** applying the plan in a sandbox-runner test lets the agent create
  `src/new.rs`, and denies modifying, deleting or renaming `src/lib_tests.rs`.

### AG-REQ-101 [L2] Repository-level roles

When `$GATE_DEFAULT_BRANCH_DIR/.factory/roles.yaml` (or `--repo-roles`) exists, agent-gate shall
use it instead of the pack roles, and shall record `source: repository` in its outputs.

### AG-REQ-102 [L2] `check-path` command

`agent-gate check-path --roles <file> --role <role> <path>...` shall report each path's access
and shall exit non-zero if any path is not W. It is for use by local hooks.

### AG-REQ-103 [L2] Optional hook configuration

agent-gate may emit Claude Code and Copilot hook configuration that calls `check-path` for
human-led use. Its documentation shall state that it is feedback only and not the enforcement
path.

### AG-REQ-104 [L2] Boundaries only

agent-gate shall contain no formatting, linting, stub, build or test checks.

- **AC1:** a code search for invocations of `cargo fmt`, `clippy` or `nextest` outside test
  fixtures and docs finds nothing.

---

## After factory role complete

### AG-REQ-150 Push ruleset generation

agent-gate may emit GitHub push ruleset definitions restricting file paths per role identity,
where the GitHub plan supports them. Applying them is out of scope.

### AG-REQ-151 Commit signature verification

agent-gate may verify commit signatures against per-role public keys from a trusted tree. Commits
whose signatures are missing or invalid would then be violations, closing the author-spoofing
gap (see [security.md](security.md), T-02).
