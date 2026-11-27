# Interface: mount plan (v1)

**Schema:** [`schemas/mount-plan/v1.schema.json`](../../../schemas/mount-plan/v1.schema.json)
(JSON Schema draft 2020-12).
**`$id`:** `urn:brightsmiths:agent-gate:mount-plan:1`.
**Producer:** `agent-gate mount-plan` or the library. **Consumer:** sandbox-runner.
**Decision record:** [ADR-0003](../../adr/ADR-0003-mount-plan-format.md).

## Request

| Input | Required | Meaning |
| --- | --- | --- |
| roles policy | yes | See [roles-input.md](roles-input.md) |
| role | yes | An agent role in the policy. `human` is refused |
| checkout | yes | Directory holding the prepared working tree |
| narrowing globs | no | The stage contract's `outputs.writable_paths`. Intersected with the role's write set |

## Document

```json
{
  "schema": "urn:brightsmiths:agent-gate:mount-plan:1",
  "role": "oracle",
  "zone": "B",
  "policy": {
    "source": "pack",
    "digest": "sha256:9f2c…"
  },
  "rules": {
    "write": ["src/**/*_tests.rs", "tests/*.rs", "tests/fixtures/**", "tests/snapshots/**", "tests/locked/**"],
    "write_except": [],
    "read_only": ["spec/**", ".factory/**", "risk-map.yaml", "AGENTS.md", "CLAUDE.md", "**/AGENTS.md", "**/CLAUDE.md"],
    "absent": ["src/**", "tests/own/**"],
    "narrowing": []
  },
  "entries": [
    { "path": "",                 "kind": "dir",  "access": "rw" },
    { "path": "Cargo.toml",       "kind": "file", "access": "ro" },
    { "path": "spec",             "kind": "dir",  "access": "ro" },
    { "path": "spec/contracts.md","kind": "file", "access": "ro" },
    { "path": "src",              "kind": "dir",  "access": "rw" },
    { "path": "src/lib.rs",       "kind": "file", "access": "absent" },
    { "path": "src/lib_tests.rs", "kind": "file", "access": "rw" },
    { "path": "tests",            "kind": "dir",  "access": "rw" },
    { "path": "tests/api.rs",     "kind": "file", "access": "rw" },
    { "path": "tests/own",        "kind": "dir",  "access": "absent" }
  ]
}
```

| Field | Meaning |
| --- | --- |
| `schema` | Format and major version |
| `role`, `zone` | As in the policy |
| `policy.source` | `pack` (L1) or `repository` (L2, [ADR-0009](../../adr/ADR-0009-repository-level-roles-file.md)) |
| `policy.digest` | `sha256:` of the raw policy bytes |
| `rules` | The role's expanded glob lists (no `@name`) plus the narrowing. With these, sandbox-runner can judge paths that do not exist yet, for example for diagnostics. The protected floor always applies and is not listed |
| `entries[]` | Sorted by `path` bytes. `""` is the checkout root |
| `entries[].kind` | `file`, `dir` or `symlink`. Symlinks are never followed |
| `entries[].access` | `rw`, `ro` or `absent` |

## Semantics

- **Files and symlinks:** access = the classification of their path. W becomes `rw`, R becomes
  `ro`, A becomes `absent`. With narrowing, a W path outside the narrowing becomes `ro`.
- **Directories:**
  - `rw` if some path below the directory, existing or not, could be W. This lets the agent
    create files that match the write globs.
  - Otherwise `absent` if every existing descendant is `absent` and no path below it could be W
    or R.
  - Otherwise `ro`.
- **No entries below an `absent` directory.**
- **`.git/` is excluded.** sandbox-runner decides how the agent commits.
- **Paths that are not in the checkout** (for example holdouts, or the harness) are not listed.
  They are absent by construction.

## Limits of L1 enforcement

A directory-level mount mechanism cannot make one file `ro` inside an `rw` directory. Two
examples:

- `src/lib_tests.rs` for `builder`;
- `Cargo.toml` at the root for `oracle`, which is `ro` while the root is `rw`.

At L1, sandbox-runner should apply per-file read-only permissions where its provider allows it.
Either way, the scope check catches any change. L2 adds attributes that make these files
tamper-proof inside the sandbox.

## L2 additions (planned, minor revision)

Optional entry fields:

| Field | Values | Meaning |
| --- | --- | --- |
| `owner` | `agent`, `locked` | Owner class. sandbox-runner maps each class to a UID |
| `mode` | octal string, e.g. `"0444"`, `"1775"` | File mode to apply |
| `sticky` | boolean | Sticky bit on directories (also encoded in `mode`) |

Rules (from [ADR-0007](../../adr/ADR-0007-colocated-locked-files.md)):

- an `ro` file inside an `rw` directory gets `owner: locked`, `mode: "0444"`;
- an `rw` directory that contains such a file gets `owner: locked`, `mode: "1775"`,
  `sticky: true`;
- an `rw` file gets `owner: agent`.

## Versioning

- `schema` carries the major version.
- Adding optional fields (such as the L2 fields) is a minor revision. Consumers must ignore
  fields they do not know **only** across minor revisions of the same major. The schema allows
  this by declaring the L2 fields from v1.
- Removing or renaming fields, or changing semantics, needs `mount-plan:2`.
