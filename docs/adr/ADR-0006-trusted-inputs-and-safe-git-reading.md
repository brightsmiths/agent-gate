# ADR-0006: Trusted inputs only from trusted trees; git read through a library

**Status:** Proposed
**Date:** 2026-11-27

## Context

Inside gate-warden's sandbox, `GATE_WORKSPACE` holds the PR content under judgement. A PR can
change `.factory/identities.yaml`, add a `roles.yaml`, or add `.gitattributes` and other files.
gate-warden mounts two trees read-only, and these are the only trusted policy sources:

- `GATE_DEFAULT_BRANCH_DIR`, the default branch at `config_sha`;
- `GATE_HARNESS_DIR`, the harness at the pinned commit.

Reading git through the `git` binary can also execute repository-controlled behaviour, such as
filters, textconv, hooks or `core.fsmonitor`, depending on configuration.

## Decision

1. **Trusted inputs come only from trusted locations.**
   - In gate-warden mode, the roles policy is read from
     `$GATE_HARNESS_DIR/disciplines/<discipline>/roles.yaml`. The discipline comes from the pin
     at `$GATE_DEFAULT_BRANCH_DIR/.factory/pin.yaml`.
   - The identity map is read from `$GATE_DEFAULT_BRANCH_DIR/.factory/identities.yaml`.
   - From L2, a repository-level `.factory/roles.yaml` is also read from
     `$GATE_DEFAULT_BRANCH_DIR`.
2. **Policy paths inside the workspace are refused.** In gate-warden mode, if an explicit
   `--roles` or `--identities` path resolves inside `GATE_WORKSPACE`, the result is `error`.
3. **Git is read through a library behind a port.** agent-gate never spawns `git`. It reads only
   objects: commits, parents, trees and tree-entry modes and IDs. It never applies repository
   config, attributes, filters, textconv or hooks, and never reads file content beyond what it
   needs to tell entry types apart.
4. **No network.** agent-gate never opens a socket.

## Consequences

- A PR cannot weaken its own scope check.
- agent-gate depends on a git library. It needs to support commit walking and tree diffs on
  repositories that gate-warden fetches, which may be shallow down to the merge base.
- A missing object (history too shallow) is an `error`, never a silent pass.

## Alternatives considered

- **Shell out to `git` with hardened flags:** this relies on every flag being correct across git
  versions. The attack surface is larger and harder to test.
- **Trust the gate definition to pass correct paths:** a mistake in the gate definition would
  silently read policy from the PR.
