# ADR-0007: Colocated locked files: other owner, `0444`, sticky `1775` directories

**Status:** Proposed (L2)
**Date:** 2026-11-27

## Context

Rust unit tests live in sibling files (`src/**/*_tests.rs`). Those files are locked by the
oracle while the builder writes `src/**` next to them. A directory-level read-only mount
cannot protect one file inside a writable directory. If the agent owns a file, it can `chmod`
it back to writable. Even when it cannot write a file, it can delete or rename the file if it
can write the directory.

## Decision

From L2, mount plan entries carry the file system attributes sandbox-runner applies:

- **Locked files** (`ro` files inside an `rw` directory): owned by a *locked* UID that is not the
  agent's, mode `0444`.
- **Directories that contain locked files and are `rw` for the role:** mode `1775` with the
  sticky bit, owned by the locked UID, with the agent in the directory's group.
- **Agent-writable files:** owned by the agent UID.
- The plan names **owner classes** (`agent`, `locked`), never numeric UIDs. sandbox-runner maps
  each class to a UID.

As a result, the agent can create new files in `src/`. It cannot modify, delete or rename
locked files, and it cannot change their mode.

## Consequences

- Enforcement moves from "detected at scope check" to "prevented in the sandbox" for colocated
  files. The scope check stays authoritative.
- sandbox-runner must support per-file ownership in every provider. This is a cross-repository
  requirement.
- The plan's schema gains optional fields. Adding optional fields is a minor schema revision.

## Alternatives considered

- **Move every locked test to a separate directory:** conflicts with Rust's sibling-test
  convention, which the harness relies on.
- **Use an overlay filesystem with a read-only lower layer for locked files:** the agent could
  still delete through a whiteout, and support differs between providers.
