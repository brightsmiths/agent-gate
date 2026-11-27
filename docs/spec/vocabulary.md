# Vocabulary

Domain concepts used across this specification. Rust type names are suggestions for the
interface designer.

## Policy concepts

### Role (`RoleName`)

- **Description:** an identity role from the harness roles policy, such as `oracle` or
  `builder`. Each role maps to exactly one trust zone.
- **Identifier:** lower-kebab-case string, as in the harness schema conventions.
- **Constraints:** `human` is reserved and must not appear in a roles policy.

### Human role

- **Description:** the reserved role for commits by people. It has no path restriction in the
  scope check and cannot be used for a mount plan.
- **Lifespan:** built in. Identities are assigned to it only through the identity map.

### Agent role

- **Description:** any role defined in the roles policy, that is, any role other than `human`.

### Zone

- **Values:** `A`, `B`, `C`, `D`, `E`. agent-gate carries the zone into mount plans and validates
  it. It does not interpret it.

### Roles policy (`Policy`)

- **Description:** the validated content of one roles document
  (`urn:brightsmiths:harness:roles:1`): path sets and roles.
- **Fields:** the schema major, path sets, roles, source (`pack` or `repository` from L2), and a
  digest (SHA-256 of the raw bytes).
- **Constraints:** immutable once loaded. There is exactly one policy per evaluation.

### Path set

- **Description:** a named list of globs in the policy, referenced as `@name`.
- **Constraints:** contains globs only, with no nested `@` references.

### Glob (`Glob`)

- **Description:** a repository-relative path pattern with gitignore-style `**`. See
  [interfaces/roles-input.md](interfaces/roles-input.md#glob-semantics).
- **Constraints:**
  - no leading `/`, no `..` segments, no `!` negation;
  - case-sensitive;
  - `*` does not cross `/`.

### Role rule set

- **Description:** a role's `write`, `write_except`, `read_only` and `absent` glob lists, after
  `@name` expansion.

### Protected floor

- **Description:** the built-in glob `.factory/**`. Paths matching it are never writable by an
  agent role, whatever the policy says.

### Access (`Access`)

- **Values:** `W` (writable; `rw` in plans), `R` (read-only; `ro`), `A` (absent; `absent`).
- **Semantics:** the classification result for one (role, path). See
  [ADR-0002](../adr/ADR-0002-roles-from-the-harness.md).

### Narrowing

- **Description:** an optional list of globs (the stage contract's `outputs.writable_paths`)
  that is intersected with a role's write set for one mount plan. It never widens access.

## Mount plan concepts

### Checkout

- **Description:** a prepared working tree of the target repository at the stage's base commit,
  on the sandbox-runner host.
- **Constraints:** `.git/` is not classified. sandbox-runner owns it.

### Mount plan (`MountPlan`)

- **Description:** the enumerated, provider-neutral access plan for one role over one checkout.
  See [interfaces/mount-plan.md](interfaces/mount-plan.md).
- **Fields:** schema, role, zone, policy source and digest, expanded rules (including narrowing),
  and entries.

### Mount entry

- **Fields:** a repository-relative path, kind (`file`, `dir`, `symlink`) and access (`rw`, `ro`,
  `absent`). *(L2)* owner class (`agent`, `locked`), mode and sticky flag.
- **Constraints:** sorted by path bytes. There are no entries below an `absent` directory.

### Owner class *(L2)*

- **Values:** `agent` and `locked`. sandbox-runner maps each class to a UID.

## Scope check concepts

### Commit range (`CommitRange`)

- **Description:** `base..head`, the commits reachable from `head` and not from `base`.
- **Constraints:** `base` must be an ancestor of `head` or equal to it.

### Identity

- **Description:** the email in a commit's author or committer field.
- **Matching:** exact after ASCII lower-casing, with no wildcards.

### Identity map (`IdentityMap`)

- **Description:** a mapping from identity to role name, plus a list of pass-through committers.
  See [interfaces/identity-map.md](interfaces/identity-map.md).
- **Constraints:**
  - every mapped role must exist in the policy or be `human`;
  - each identity appears at most once.

### Pass-through committer

- **Description:** an identity allowed as committer whatever the author's role, such as
  GitHub's web-flow identity used by UI merges and edits. It is never valid as an author.

### Changed path

- **Description:** a path whose tree entry differs between a commit and its parent: added,
  modified (content or mode), deleted, or either side of a rename. For merge commits, a path
  that differs from every parent.

### Special entry

- **Description:** a tree entry that is a symlink (mode `120000`) or a submodule gitlink (mode
  `160000`).

### Violation (`Violation`)

- **Fields:** commit ID, path (if any), rule, role (if resolved).
- **Rules:**
  - `out-of-scope`: the path is not W for the role;
  - `protected-path`: the path is under the protected floor;
  - `unknown-identity`: the author is not in the identity map;
  - `mixed-identity`: the committer resolves to a different role and is not a pass-through;
  - `special-entry`: an agent role added or modified a symlink or gitlink;
  - `invalid-path`: the path is not valid UTF-8 or contains control characters.

### Scope report

- **Description:** the business-logic result of a scope check: commits examined, paths
  examined, and violations in a deterministic order. Emitted as `gate-result/v1`.

### Check status

- **Values:** `pass`, `fail`, `error`. These are gate-warden's values. There is no `skip`.

## Error concepts

All errors yield status `error` and exit code `2`. No error may yield `pass`.

| Error | Meaning | Security note |
| --- | --- | --- |
| `SchemaMajorUnsupported` | The `schema:` field names a major version agent-gate does not support | Fail closed on newer policy |
| `PolicyInvalid` | Unknown field, duplicate key, unresolved `@name`, invalid glob, reserved role, bad zone | Prevents a typo from widening access |
| `IdentityMapInvalid` | Unknown role, duplicate identity, unknown field | |
| `RoleNotFound` | The requested role is not in the policy | |
| `HumanRoleNotPlannable` | `mount-plan` was asked for `human` | |
| `UntrustedPolicyLocation` | In gate-warden mode, a policy or identity path lies inside `GATE_WORKSPACE` | Stops a PR weakening its own check |
| `RangeInvalid` | `base` is not an ancestor of `head`, or a commit ID cannot be resolved | |
| `HistoryIncomplete` | A needed object is missing (shallow clone) | Never treated as "no commits" |
| `CheckoutUnreadable` | I/O error while enumerating the checkout | |
| `LimitExceeded` | A configured limit (commits, paths, input size) was exceeded | DoS protection, fail closed |
| `EnvironmentIncomplete` | A required `GATE_*` variable is missing in gate-warden mode | |
