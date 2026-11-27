# Edge cases and failure modes

## Policy

| Case | Behaviour |
| --- | --- |
| A role with no lists at all | Valid. Every path is R (default snapshot), so the role can write nothing |
| The same glob in `write` and `absent` | W (an explicit pattern beats `absent`) |
| The same glob in `write` and `read_only` | R (AS-05) |
| `write_except` without a matching `write` | No effect on access. The path follows steps 3–5 |
| `@name` used in `write_except` that names an empty set | Valid. Nothing is excluded |
| Glob `**` alone | Matches every path. Valid, but the protected floor still applies |
| YAML anchors and aliases, or multiple documents | `PolicyInvalid` (keeps the input simple to review) |
| A UTF-8 BOM in the YAML | Accepted and stripped |
| A policy file over the size limit | `LimitExceeded` |

## Mount plan

| Case | Behaviour |
| --- | --- |
| Empty checkout | One entry: `""` with the root's access |
| A directory that will hold W files but does not exist yet (for example `tests/own/`) | Not listed. The parent is `rw` because a path below it could be W. sandbox-runner lets the agent create it |
| `rw` directories are coarse | `rw` means "may create *some* path here". It does not mean any name is allowed. For example, the root is `rw` for `builder` because of `Cargo.toml`. A new root file such as `x.txt` passes the mount layer, and the scope check reports it |
| `.git` as a file (worktree or submodule pointer) | Excluded like `.git/` |
| Nested `.git/` inside a subdirectory (vendored repository) | Listed and classified like any other directory. Committing it would be a gitlink, which is `special-entry` |
| A symlink to a directory | Kind `symlink`. Not descended |
| Other special files (FIFO, socket, device) | `CheckoutUnreadable`. A prepared checkout must not contain them |
| Non-UTF-8 file names in the checkout | `CheckoutUnreadable`. A plan cannot represent them faithfully in JSON |
| Case-insensitive host file system | Not supported for planning. sandbox-runner hosts are Linux. Recorded in operations |

## Scope check

| Case | Behaviour |
| --- | --- |
| `base == head` | `pass`, zero commits |
| `base` is not an ancestor of `head` | `error` (`RangeInvalid`). gate-warden passes the merge base, so this means misuse |
| `head` is an ancestor of `base` (the range would be empty but reversed) | `error` (`RangeInvalid`) |
| Shallow history missing `base` or a parent inside the range | `error` (`HistoryIncomplete`) |
| A root commit (no parent) inside the range | Every entry of its tree is a changed path (added) |
| An empty commit (tree equal to its parent's) | No changed paths. Still counted, and its identity is still checked |
| An octopus merge (more than two parents) | Combined diff across all parents. Same rule |
| A mode-only change (`100644` to `100755`) | A changed path |
| Changing a file to a symlink, or a symlink to a file | Changed. Adding a symlink gives `special-entry`. Replacing a symlink with a file is a normal change |
| Deleting a symlink or a gitlink | A normal changed path. Not `special-entry` |
| A deleted file | The path must be W for the role. Deleting a locked test is `out-of-scope` |
| An agent commit whose author is mapped but whose committer is unmapped | `mixed-identity` |
| Both author and committer are pass-through only | `unknown-identity` |
| A commit violates both identity and path rules | An identity violation (`unknown-identity`) stops path evaluation for that commit, because there is no role to evaluate against. `mixed-identity` still evaluates paths under the author's role |
| Email case differs from the map (`Builder-Bot@X`) | Matches. ASCII lower-casing is applied |
| A path containing `\t`, `\n` or `\0`-like control characters | `invalid-path` for agent roles. Not reported for the human role, which has no path restrictions |
| Two paths in one commit that differ only by case | Each is classified separately and byte-exactly |
| A very long path (over 4096 bytes) | Classified as normal. Truncated with an ellipsis in the finding message only |

## gate-warden mode

| Case | Behaviour |
| --- | --- |
| `.factory/pin.yaml` missing on the default branch | `error` (`EnvironmentIncomplete`). gate-warden itself also fails such repositories |
| `.factory/identities.yaml` missing on the default branch | `error` |
| The pin names a discipline with no `roles.yaml` in the harness | `error` |
| `GATE_RESULT_FILE` already exists | Overwritten atomically. gate-warden guarantees a fresh path, so this is defensive |
| The result file cannot be written | Exit `2`, with a stderr diagnostic. gate-warden records a missing result as `error` |
| A symlinked `GATE_HARNESS_DIR` that resolves inside `GATE_WORKSPACE` | Detected by canonicalisation. `UntrustedPolicyLocation` |
