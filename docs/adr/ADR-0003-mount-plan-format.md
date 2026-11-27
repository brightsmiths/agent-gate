# ADR-0003: Mount plan is an enumerated, provider-neutral, versioned JSON document

**Status:** Proposed
**Date:** 2026-11-27

## Context

sandbox-runner prepares each agent's workspace outside the microVM and applies a mount plan.
The provider is microsandbox for reference, with Firecracker or Kata as alternatives. The
experiment's README described Docker bind mounts. Different providers materialise workspaces
differently: bind mounts, a copied-in disk image, or overlays.

Globs alone are not enough for a provider. Bind mounts work per directory, but locked files can
sit next to source files (`src/**/*_tests.rs`), and the oracle role must see `src/` test
siblings without seeing the production source next to them.

## Decision

- `agent-gate mount-plan` reads one role, the roles policy and a prepared checkout. It emits a
  JSON document with `schema: urn:brightsmiths:agent-gate:mount-plan:1`.
- The plan is **enumerated**. It lists every entry in the checkout except `.git/`, with its
  kind (`file`, `dir`, `symlink`) and access (`rw`, `ro`, `absent`). If a whole subtree is
  absent, only its top directory is listed.
- **Directory access** means:
  - `rw`: the role may create new entries inside it;
  - `ro`: the role may read it but create nothing;
  - `absent`: nothing in it is visible.
- The plan also carries the role's **expanded rules** (`write`, `write_except`, `read_only`,
  `absent`, narrowing), so new paths can be judged, and a
  digest of the policy it came from.
- The plan does not name any provider mechanism. sandbox-runner chooses how to realise it.
- An optional **narrowing** input (the stage contract's `outputs.writable_paths`) is intersected
  with the role's write set. Narrowing can never widen access.
- From L2, entries for locked files carry ownership and mode
  ([ADR-0007](ADR-0007-colocated-locked-files.md)).
- agent-gate owns the schema (`schemas/mount-plan/v1.schema.json`) until the harness adopts it
  (assumption AS-09).

## Consequences

- sandbox-runner needs no glob engine and no knowledge of policy semantics.
- The plan's size grows with the checkout. A JSON plan for 100,000 files is a few megabytes,
  which is acceptable.
- At L1, a per-file `ro` inside an `rw` directory may not be enforceable by a directory-level
  mount mechanism. The scope check catches any violation, and L2 closes the gap.

## Alternatives considered

- **Globs only:** pushes policy evaluation into sandbox-runner, so the same policy would be
  evaluated twice.
- **Provider-specific output (for example a Docker `-v` list):** this is the experiment's gap,
  and it ties agent-gate to one provider.
- **Directory-level plan only:** cannot express colocated locked files or a partially absent
  `src/`.
