# Interface: roles policy input

**Owner of the schema:** [brightsmiths/harness](https://github.com/brightsmiths/harness)
(`urn:brightsmiths:harness:roles:1`, `docs/specs/schemas.md#roles`).
**agent-gate role:** consumer. This page records how agent-gate reads that schema. Where it adds
an interpretation, the interpretation is flagged and listed in
[assumptions.md](../assumptions.md).

## Sources

| Mode | Source | Level |
| --- | --- | --- |
| Explicit | `--roles <file>` | L1 |
| gate-warden mode | `$GATE_HARNESS_DIR/disciplines/<discipline>/roles.yaml`, where `<discipline>` is the `discipline` field of `$GATE_DEFAULT_BRANCH_DIR/.factory/pin.yaml` (`urn:brightsmiths:harness:pin:1`) | L1 |
| Repository override | `$GATE_DEFAULT_BRANCH_DIR/.factory/roles.yaml` or `--repo-roles <file>`. It **replaces** the pack file ([ADR-0009](../../adr/ADR-0009-repository-level-roles-file.md)) | L2 |

From the pin file, agent-gate reads only `schema` and `discipline`. Other pin fields are ignored,
but the document must still be well-formed YAML with a supported schema major.

## Fields agent-gate reads

```yaml
schema: urn:brightsmiths:harness:roles:1
path_sets:
  locked_tests: ["src/**/*_tests.rs", "tests/*.rs", "tests/fixtures/**", "tests/snapshots/**"]
  manifest: ["tests/locked/**"]
  own_tests: ["tests/own/**"]
  factory: [".factory/**", "risk-map.yaml", "AGENTS.md", "CLAUDE.md", "**/AGENTS.md", "**/CLAUDE.md"]
config_guard: { ... }            # parsed for validity, not interpreted (oracle-guard owns it)
roles:
  oracle:
    zone: B
    write: ["@locked_tests", "@manifest"]
    absent: ["src/**", "@own_tests"]
    read_only: ["spec/**", "@factory"]
  builder:
    zone: C
    write: ["src/**", "@own_tests", "Cargo.toml", "Cargo.lock"]
    write_except: ["@locked_tests"]
    read_only: ["@locked_tests", "@manifest", "spec/**", "@factory"]
```

- **Unknown top-level or role fields** are rejected (`additionalProperties: false` in the harness
  conventions).
- **`config_guard`** is accepted and checked only for shape. agent-gate does not use it.
- **`@name`** may appear in any role glob list. A `@name` inside `path_sets` is rejected.
- Every role list is optional. A missing list is empty.

## Classification rule

For an agent role `r` and a repository-relative path `p`:

| Step | Condition | Access |
| --- | --- | --- |
| 1 | `p` matches `.factory/**` (protected floor) and step 2 would give W | R |
| 2 | `p` ∈ `write` ∧ `p` ∉ `write_except` ∧ `p` ∉ `read_only` | W |
| 3 | `p` ∈ `write` ∨ `p` ∈ `read_only` | R |
| 4 | `p` ∈ `absent` | A |
| 5 | otherwise | R |

**Flagged interpretation (AS-05):** step 2 excludes `read_only`, so `read_only` beats `write`.
The harness schema states only that `write_except` beats `write` and that explicit patterns beat
`absent`.

## Glob semantics

Following the harness convention ("gitignore-style `**`"):

- Patterns and paths are repository-relative, `/`-separated and UTF-8. Matching is
  **case-sensitive** and byte-exact.
- `*` matches any sequence of characters except `/`.
- `?` matches one character except `/`.
- `[...]` matches a character class (no `/`).
- `**` as a **whole segment** matches zero or more segments:
  - `a/**` matches everything below `a`;
  - `**/b` matches `b` at any depth;
  - `a/**/b` matches `a/b` and `a/x/y/b`.
- `**` that is not a whole segment is treated as `*`.
- **A pattern without `/`** matches only at the repository root. This differs from gitignore and
  is deliberate: `Cargo.toml` means `./Cargo.toml` only. Use `**/Cargo.toml` to match at any
  depth.
- A pattern naming a directory does not match its contents. Use `dir/**`.
- These are rejected:
  - a leading `/`;
  - a trailing `/`;
  - `..` or `.` segments;
  - `!` negation;
  - brace expansion `{a,b}`;
  - empty patterns;
  - backslashes.

**Flagged interpretation (AS-06):** "pattern without `/` matches only at the root" needs
confirmation from the harness, because the harness `factory` path set lists both `AGENTS.md` and
`**/AGENTS.md`, which suggests the same reading.

## Validation errors

| Defect | Error |
| --- | --- |
| `schema` missing, or not `urn:brightsmiths:harness:roles:<major>` | `PolicyInvalid` |
| Major ≠ 1 | `SchemaMajorUnsupported` |
| Unknown field, duplicate YAML key, non-string glob | `PolicyInvalid` |
| `@name` undefined or nested | `PolicyInvalid` |
| Invalid glob | `PolicyInvalid` |
| Role named `human`; role name not lower-kebab-case | `PolicyInvalid` |
| `zone` not in `A`–`E` | `PolicyInvalid` |
| File larger than the limit | `LimitExceeded` |
