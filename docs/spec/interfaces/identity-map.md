# Interface: identity map (v1)

**Schema:** [`schemas/identities/v1.schema.json`](../../../schemas/identities/v1.schema.json)
(JSON Schema draft 2020-12, instantiated as YAML).
**`$id`:** `urn:brightsmiths:agent-gate:identities:1`.
**Owner:** agent-gate for now. It may move to the harness (AS-10).
**Decision record:** [ADR-0004](../../adr/ADR-0004-scope-check-semantics.md).

## Location

- In gate-warden mode: `$GATE_DEFAULT_BRANCH_DIR/.factory/identities.yaml`. This is the target
  repository's default branch: human-owned, under the protected floor, and never read from the
  PR.
- Explicitly: `--identities <file>`.

## Format

```yaml
schema: urn:brightsmiths:agent-gate:identities:1
identities:
  - email: "1234567+bs-oracle[bot]@users.noreply.github.com"
    role: oracle
  - email: "1234568+bs-builder[bot]@users.noreply.github.com"
    role: builder
  - email: "maintainer@example.org"
    role: human
pass_through_committers:
  - "noreply@github.com"
```

| Field | Required | Meaning |
| --- | --- | --- |
| `schema` | yes | `urn:brightsmiths:agent-gate:identities:1` |
| `identities[]` | yes (may be empty) | Identity → role entries |
| `identities[].email` | yes | Commit email. Matched exactly after ASCII lower-casing. No wildcards |
| `identities[].role` | yes | A role in the policy, or `human` |
| `pass_through_committers[]` | no | Emails accepted as committer for any author role. Never valid as an author |

## Rules

- Each email may appear at most once across `identities`. It may not also appear in
  `pass_through_committers`.
- Every `role` must exist in the policy in use, or be `human`. Otherwise the result is
  `IdentityMapInvalid`.
- Unknown fields are rejected.
- **Author resolution:**
  - mapped author → that role;
  - unmapped author → `unknown-identity`;
  - author listed only as pass-through → `unknown-identity`.
- **Committer check:** the committer must map to the same role as the author, or be a
  pass-through committer. Otherwise → `mixed-identity`.

## Why emails

GitHub App bot commits use the form `<id>+<slug>[bot]@users.noreply.github.com`. Git stores no
other stable identity in a commit. Emails can be forged by anyone who writes the commit, so the
map only gives correct attribution together with sandbox-runner stamping identities on push
(AS-11) and human review. Signature verification is planned for after the factory role is
complete (AG-REQ-151).
