# ADR-0009: A repository-level `.factory/roles.yaml` replaces the pack roles

**Status:** Proposed (L2)
**Date:** 2026-11-27

## Context

The harness repository is itself a factory run target from M3. Its `harness-author` role must
not exist in any pack's `roles.yaml`. The harness therefore defines it in its own
`.factory/roles.yaml` and requires agent-gate to support a repository-level roles file
("replaces or extends the pack's mapping").

## Decision

- When the default-branch tree of the target repository contains `.factory/roles.yaml`,
  agent-gate uses it **instead of** the pack's `roles.yaml`. It is never merged with the pack
  file.
- The file uses the same schema (`urn:brightsmiths:harness:roles:1`) and the same validation.
- It is read only from the trusted default-branch tree
  ([ADR-0006](ADR-0006-trusted-inputs-and-safe-git-reading.md)). It sits under the protected
  floor, so no agent can write it.
- The output records which source was used (`pack` or `repository`) and its digest.

## Consequences

- Semantics stay simple: there is exactly one policy per evaluation.
- A repository that only needs to add a role must copy the pack roles it still uses.

## Alternatives considered

- **Extend (merge) with the pack:** merge rules for overlapping roles and path sets would be a
  second policy language and hard to review.
- **Let the gate definition pass a different `--roles` path:** gate definitions are pack-wide,
  while the override is per repository.
