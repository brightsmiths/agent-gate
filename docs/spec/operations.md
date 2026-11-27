# Operations

agent-gate is not deployed as a running service. Operating it means distributing a binary and
library, versioning them, and documenting how consumers invoke them.

## Distribution

- **Binary:** static Linux x86_64 and aarch64 builds, attached to GitHub Releases with SHA-256
  checksums. Releases go through release-regent once it is available, and are built by hand
  before then.
- **Library:** the workspace crates are published as git dependencies, pinned by tag. crates.io
  publishing is optional.
- **Images:** gate-warden's gate image and sandbox-runner's host image include a pinned
  agent-gate binary. Changing the version means changing the image digest, which is reviewed.

## Versioning

- SemVer:
  - a change in classification semantics, output schema major, or CLI behaviour that can turn a
    `pass` into `fail` or the reverse is a **major** version;
  - new optional output fields and new commands are **minor**;
  - bug fixes are **patch**.
- The release notes list the supported input schema majors (roles, pin, identities) and output
  formats (`mount-plan:1`, `gate-result/v1`).

## Consumer integration

### gate-warden (G6-lite `scope-check`)

Gate definition (harness):

```yaml
- id: scope-check
  run: ["agent-gate", "scope-check"]
  adapter: native
```

gate-warden provides the `GATE_*` environment, a workspace with history down to the merge base
(AS-13), and the read-only default-branch and harness trees.

### sandbox-runner

1. Prepare the checkout at the stage's base commit on the host.
2. Run `agent-gate mount-plan --roles <pinned roles.yaml> --role <identity_role>
   --checkout <dir> --writable-paths <stage contract outputs.writable_paths>`. Alternatively,
   call the library.
3. Apply the plan (provider-specific). Boot the microVM.
4. After the attempt, run `agent-gate scope-check --roles … --as-role <identity_role>
   --range <base>..<agent head> --repo <host clone>`.
5. Only if the exit code is `0`: re-stamp the author and committer as the role's App identity,
   then push with the role token.

### Target repositories

Each target repository's default branch must contain:

- `.factory/pin.yaml` (harness pin, which already exists for gate-warden);
- `.factory/identities.yaml` (identity map). It lists every role App's commit email, every human
  who commits to the repository, and `noreply@github.com` as a pass-through committer if UI
  merges or edits are used.

## Observability

- agent-gate emits no telemetry of its own. It has no network access.
- gate-warden publishes the scope-check outcome in its check run, and sandbox-runner logs the
  pre-check result.
- stderr carries a structured, single-line summary (command, version, inputs digest, status,
  counts, duration) for operator logs.

## Performance targets (proposed – to be revisited)

| Operation | Target |
| --- | --- |
| `scope-check`, 500 commits, 5,000 changed paths | p95 ≤ 2 s |
| `mount-plan`, 100,000-entry checkout | p95 ≤ 3 s, ≤ 256 MiB RSS |
| `validate` | ≤ 100 ms |

## Runbook

| Symptom | Likely cause | Action |
| --- | --- | --- |
| Every PR in a repository gets `error` with `EnvironmentIncomplete` | `.factory/identities.yaml` is missing on the default branch | A human adds it |
| A new role App's commits get `unknown-identity` | Its email is not in the identity map | A human adds it to the map |
| `HistoryIncomplete` | gate-warden fetched too shallow | Fix gate-warden's workspace preparation |
| `SchemaMajorUnsupported` after a harness upgrade | The harness bumped the roles major | Upgrade agent-gate in the images first |
