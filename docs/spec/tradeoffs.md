# Tradeoffs

Alternatives considered for the main decisions. Each ADR has the full record.

| Topic | Chosen | Alternatives | Why |
| --- | --- | --- | --- |
| Shape | Library plus stateless CLI ([ADR-0001](../adr/ADR-0001-rust-library-and-stateless-cli.md)) | Networked service; shell scripts; library only | gate-warden must recompute in its own sandbox. A service adds attack surface and credentials |
| Policy format | Consume the harness roles schema ([ADR-0002](../adr/ADR-0002-roles-from-the-harness.md)) | Own TOML format (as in the experiment) | The harness owns cross-service schemas. One format, no drift |
| `write` and `read_only` overlap | `read_only` wins | `write` wins; listing order | Restriction wins. A typo cannot grant write access to locked paths |
| Protected floor | Built in, `.factory/**` | Configurable; none | It must survive a misconfigured policy |
| Plan granularity | Enumerated per entry ([ADR-0003](../adr/ADR-0003-mount-plan-format.md)) | Globs only; directories only; provider-specific | Colocated locked files and a partly absent `src/` need per-entry access. Provider-neutral |
| Plan schema owner | agent-gate (proposed handover to the harness) | The harness from the start | The harness has no mount plan schema yet. Raised as AS-09 |
| Attribution | Per commit through an identity map ([ADR-0004](../adr/ADR-0004-scope-check-semantics.md)) | Net diff against the PR author; GitHub API | Mixed human and agent PRs. No network inside the gate |
| Unknown identities | Violation | Treated as human | Fail closed |
| Humans | Explicit `human` role, unrestricted | Path-restricted human roles | Humans are governed by review and CODEOWNERS. The explicit mapping keeps unknown identities failing |
| Merge commits | Combined diff (differs from every parent) | Diff against the first parent; reject merges | The first parent would blame the merger for the default branch's changes. Rejecting merges blocks "update branch" |
| Renames | Delete plus add (rename detection off) | Rename detection | Both sides must be checked anyway. Avoids heuristic similarity thresholds |
| Result format | gate-warden `gate-result/v1` ([ADR-0005](../adr/ADR-0005-scope-check-emits-gate-result-v1.md)) | Harness `gate-result:1`; both | gate-warden is the consumer and defines the emission contract. Conflict raised as AS-08 |
| Git access | Library behind a port ([ADR-0006](../adr/ADR-0006-trusted-inputs-and-safe-git-reading.md)) | `git` subprocess | Never execute repository-controlled behaviour |
| Colocated locked files | Ownership, `0444`, sticky `1775` ([ADR-0007](../adr/ADR-0007-colocated-locked-files.md)) | Move tests; overlays | Keeps Rust sibling tests. Works across providers |
| Repository roles | Replace the pack ([ADR-0009](../adr/ADR-0009-repository-level-roles-file.md)) | Merge with the pack | One policy per evaluation is easier to review |
| Hooks | Optional at L2 ([ADR-0008](../adr/ADR-0008-boundaries-only.md)) | Keep as the primary enforcement; drop | They run inside the agent process. Defence in depth only |
