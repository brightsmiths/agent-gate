# ADR-0004: Scope check attributes each commit to a role through an identity map

**Status:** Proposed
**Date:** 2026-11-27

## Context

The scope check answers one question: did every changed path belong to the role of the identity
that authored the commit? Each agent role pushes under its own GitHub App, and humans also
commit, for example when writing specs at L1, fixing a PR or merging the default branch into
it. A PR's net diff alone cannot tell who changed what.

## Decision

1. **Per-commit evaluation.** Every commit reachable from `head` and not from `base` is
   evaluated on its own.
   - A **non-merge commit** is compared with its parent.
   - A **merge commit** is evaluated on the paths that differ from **every** parent (combined
     diff). This includes conflict resolutions and "evil merge" content, and excludes content
     merged in unchanged.
2. **Identity map.** A human-owned file maps commit identities (emails) to role names
   (`urn:brightsmiths:agent-gate:identities:1`). In gate-warden mode it is read from
   `.factory/identities.yaml` in the default-branch tree.
   - The role is resolved from the commit **author**.
   - The **committer** must resolve to the same role or be listed as a pass-through committer,
     such as GitHub's web-flow identity. Otherwise the commit is a `mixed-identity` violation.
3. **Unknown identities fail.** An author not in the map is an `unknown-identity` violation.
4. **Explicit `human` role.** `human` is reserved. Commits by identities mapped to `human` are
   not limited by path, because humans are governed by review, CODEOWNERS and rulesets. They
   must still be mapped explicitly. `human` cannot be used to produce a mount plan.
5. **Agent-role commits:**
   - Each changed path (add, modify, delete, mode change, and both sides of a rename) must
     classify as W. Otherwise it is an `out-of-scope` violation, or `protected-path` under the
     floor.
   - Adding or modifying a symlink or a submodule entry is a `special-entry` violation.
   - A path that is not valid UTF-8 or contains control characters is an `invalid-path`
     violation.
6. **Every violation is reported**, not only the first, in a deterministic order.
7. **Pre-push mode** (`--as-role <role>`) attributes every commit in the range to one role
   without reading an identity map. sandbox-runner uses it before it re-stamps and pushes.

## Consequences

- Correct attribution depends on sandbox-runner stamping the role's App identity as author and
  committer on push, since the agent controls these fields inside the microVM. This is a
  cross-repository requirement (assumption AS-11).
- A human with push access could forge a bot identity. Human review on T2+ repositories reduces
  this risk. Commit signature verification is planned for after the factory role is complete.
- Humans must be listed in each repository's identity map.

## Alternatives considered

- **Check the net diff against the PR author's role:** mixed human and agent PRs would be
  misattributed, and an agent change "fixed up" by a human could not be told apart.
- **Treat unknown identities as human:** fails open.
- **Use the GitHub API for verified pusher identity:** needs network and a token inside the gate
  sandbox. This may be added later through gate-warden.
- **Reject all merge commits:** blocks the normal "update branch" flow.
