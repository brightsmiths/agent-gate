# Security

agent-gate is a security-boundary component. Its job is to stop an agent role writing outside
its paths, and it must not become the weak link itself.

## Trust boundaries

1. **Trusted inputs:**
   - the harness at the pinned commit (roles policy);
   - the default-branch tree at `config_sha` (pin, identity map, repository roles from L2);
   - arguments from sandbox-runner and gate-warden.
2. **Untrusted inputs:**
   - the PR workspace and its git objects: paths, modes, author and committer fields, tree
     shapes, object sizes;
   - the stage checkout's contents.
3. **Output consumers:** gate-warden treats agent-gate's result as untrusted check output. It
   validates the result against the schema and applies its own caps. sandbox-runner applies the
   plan.

## Threats

| ID | Threat (STRIDE) | Mitigation | Requirements / ADRs |
| --- | --- | --- | --- |
| **T-01** | **Tampering with policy through the PR.** An agent edits `.factory/identities.yaml`, adds a `roles.yaml`, or edits the pin to weaken the check | Policy and identity map are read only from trusted trees. Paths inside `GATE_WORKSPACE` are refused. `.factory/**` is a protected floor for every agent role, so the edit itself is a `protected-path` violation | AG-REQ-005, 060, 061; [ADR-0006](../adr/ADR-0006-trusted-inputs-and-safe-git-reading.md) |
| **T-02** | **Spoofing commit identity.** The agent sets the author or committer to another role's bot email (for example oracle) so it can edit locked tests | sandbox-runner pre-checks with `--as-role` (the real role) and then stamps the role identity on push (AS-11). The agent never holds a push token. A forged identity that does not match its committer gives `mixed-identity`. **Residual:** a human with push access can forge any email. This is mitigated by human review on T2+ repositories, and closed later by signature verification (AG-REQ-151) | AG-REQ-043, 050; [ADR-0004](../adr/ADR-0004-scope-check-semantics.md) |
| **T-03** | **Path confusion.** Case variants (`SRC/`), Unicode look-alikes, trailing dots or spaces, or non-UTF-8 bytes used to slip past globs | Writes are default-deny: anything not matched by `write` is not W, so variants of a writable path are violations. Matching is byte-exact and case-sensitive. Non-UTF-8 and control characters are `invalid-path`. **Residual:** a variant of a *locked* path (for example `src/a_Tests.rs`) is W for the builder. It is a new file that Rust's `#[path]` will not pick up. gate-warden runs on case-sensitive Linux | AG-REQ-003, 046 |
| **T-04** | **Symlink escape.** The agent commits a symlink in a writable directory that points at a locked file or outside the repository, so that the build reads or writes through it | Adding or modifying a symlink is a `special-entry` violation for agent roles. The mount planner never follows symlinks | AG-REQ-023, 046 |
| **T-05** | **Submodule smuggling.** A gitlink brings in code outside the policy | Adding or modifying a gitlink is a `special-entry` violation for agent roles | AG-REQ-046 |
| **T-06** | **Hostile repository attacks the reader.** `.gitattributes` filters, `core.fsmonitor`, hooks, huge trees or commit floods | Library-based reading with no process spawning, no config, no attributes and no content reads. Caps on commits, paths and entries. Exceeding a cap gives `error` | AG-REQ-070, 072; ADR-0006 |
| **T-07** | **A misconfigured policy grants broad writes.** For example a typo, `write: ["**"]`, or a missing `write_except` | Strict validation. `read_only` beats `write`. The protected floor holds. The harness is human-reviewed (H8) and pinned | AG-REQ-002, 004, 005; ADR-0002 |
| **T-08** | **Hiding changes in merge commits** | Per-commit evaluation of every commit in the range. Merge commits are evaluated on the combined diff (paths differing from every parent), so evil-merge content is attributed to the merger | AG-REQ-042 |
| **T-09** | **Fail-open on error.** A shallow clone, missing base or crash is read as "no commits" | Every error is `error` with exit `2`. `pass` is emitted only after a complete evaluation | AG-REQ-049 |
| **T-10** | **Forged or oversized result.** PR code writes `GATE_RESULT_FILE` | gate-warden's concern. scope-check runs before any PR code executes (gate-warden T-09). agent-gate writes atomically and stays within 1 MiB | AG-REQ-062 |
| **T-11** | **Mount plan and checkout drift (TOCTOU).** The checkout changes between planning and boot | sandbox-runner prepares the checkout outside the microVM before the agent starts, and plans once. The scope check is the backstop | ADR-0003 |
| **T-12** | **Information disclosure through findings.** Messages leak file contents or holdout names | Findings carry the path, rule, short SHA and role only. Paths are already visible in the PR. Holdouts are never in the checkout or in the PR range | AG-REQ-048 |
| **T-13** | **Holdout or harness exposure through mount plans** | Paths outside the checkout are never listed. Harness and holdouts are absent by construction (harness ADR-0006) | AG-REQ-021 |

## Red-team scenarios (test suite)

1. A builder commit modifies `src/foo_tests.rs`. Expect `out-of-scope`.
2. A builder commit with author set to the oracle bot and committer set to the builder bot.
   Expect `mixed-identity`.
3. A builder commit adds `src/x` as a symlink to `../tests/api.rs`. Expect `special-entry`.
4. A builder renames `tests/api.rs` to `src/api.rs`. Expect `out-of-scope` on `tests/api.rs`.
5. An agent merge commit with an evil-merge edit to a locked file. Expect `out-of-scope`.
6. A PR edits `.factory/identities.yaml` to map the builder bot to `human`. The old map is used,
   and the edit itself is `protected-path`.
7. In gate-warden mode, `--roles` points into `GATE_WORKSPACE`. Expect `error`.
8. A shallow clone missing `GATE_BASE_SHA`. Expect `error`.
9. A repository with a malicious `.gitattributes` filter and a `.git/hooks/*`. Neither is executed.
10. 20,000 commits in the range with the default cap. Expect `error` (`LimitExceeded`).
11. A path with a `\n` or invalid UTF-8 bytes. Expect `invalid-path`.
12. A policy with `write: ["**"]` for the builder. `.factory/pin.yaml` is still R.
