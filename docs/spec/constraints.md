# Constraints

Rules for implementers. They are binding.

## Language and shape

- Rust, stable toolchain pinned with `rust-toolchain.toml`.
- A cargo workspace with at least:
  - a business-logic library crate (pure);
  - an adapters crate (or modules) for the file system, git and serialisation;
  - a CLI binary crate.
- No daemon, no network, no persistent state, no `unsafe`.

## Type system

- Newtypes for `RoleName`, `RepoPath`, `RawPath`, `Glob`, `CommitId`, `Email` and `PolicyDigest`.
  Constructors validate. Invalid values cannot be represented.
- Closed enums for `Access` (`W`, `R`, `A`), `EntryKind`, `ChangeKind`, `ViolationRule`,
  `CheckStatus` and `PolicySource`.
- `Role` is either `Human` or `Agent(RoleName)`. Mount-plan functions accept only agent roles, at
  the type level.
- Raw input is decoded into DTOs, then validated into domain types. Domain types do not derive
  `Deserialize` directly.

## Errors

- Expected errors are values: `Result<T, E>` with typed error enums per layer (see the error
  table in [vocabulary.md](vocabulary.md#error-concepts)).
- No `unwrap` or `expect` on external data. Panics are for programmer errors only. The CLI
  catches any panic and turns it into exit `2` with an `error` result.
- **Fail closed:** no code path produces `pass` after an error.

## Module boundaries

- The business-logic crate must not depend on file system, git, serde format, CLI or process
  crates. This is enforced with cargo-deny `bans` for that crate.
- Only the git adapter imports the git library. Only the file system adapter touches the
  checkout.
- No discipline-specific strings (`cargo`, `_tests.rs`, `src/`) in non-test code. They come from
  policy.

## Security rules

- Never spawn processes.
- Never read repository config, attributes or hooks.
- Never read blob contents during the scope check.
- Never follow symlinks when enumerating a checkout.
- In gate-warden mode, read trusted inputs only from trusted trees (ADR-0006).
- Enforce caps on input sizes, commits, paths and entries (AG-REQ-072).
- Write result files atomically.

## Determinism

- Sort all outputs by byte order. Use canonical JSON key order.
- No timestamps, host names, durations or random values in outputs. Durations may go to stderr
  diagnostics only.

## Testing

- Sibling `*_tests.rs` unit tests and `tests/` for the public API.
- Coverage and mutation targets as in [testing.md](testing.md).
- Every L1 assertion has at least one test.

## Performance

As in [operations.md](operations.md#performance-targets-proposed--to-be-revisited). Glob sets are
compiled once per evaluation. Classification is O(number of globs) per path.
