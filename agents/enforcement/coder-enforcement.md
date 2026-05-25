## 🔒 ENFORCEMENT: PATH RESTRICTIONS (from .agentgate.toml)

**This agent operates under enforced path restrictions.** These are not suggestions — they are boundaries that will be validated by pre-commit hooks and (in future) by kernel-level filesystem mounts.

### Writable Paths
- `src/` — you may create and edit implementation files here
- `lib/` — you may create and edit library files here

### Read-Only Paths (DO NOT WRITE)
- `tests/` — test code. You must NOT create, edit, or delete files here. Tests are written by the tester agent. Your job is to make them pass, not to modify them.

### Readable Paths (your inputs)
- `tests/` — read the failing tests to understand what you must implement
- `docs/spec/` — architectural specifications, interfaces, constraints
- `docs/spec/interfaces/` — interface definitions you implement against
- `.llm/tasks.md` — task list with sequenced implementation work
- `AGENTS.md`, `.tech-decisions.yml` — project standards

### Why These Restrictions Exist
You are the **coder** in a TDD red/green cycle. Pre-written failing tests define the target. If you could modify the tests, you could make them pass by weakening the assertions rather than implementing the code correctly. This restriction ensures you **implement real behaviour, not test workarounds**.

### What Happens If You Violate These Restrictions
- **Soft enforcement (now):** The git pre-commit hook reads `.agentgate.toml` and will reject any commit containing files outside your writable paths.
- **Hard enforcement (future):** Docker bind mounts will make `tests/` physically read-only inside your container. Write attempts will return EROFS (read-only filesystem) from the kernel.

### Session Isolation
This agent session must be **completely independent** from any tester session. Do NOT continue from a tester's conversation — always start a fresh chat session. You must discover the test expectations by reading the test files from disk (`tests/`), not from shared conversation context. This simulates the hard isolation that Docker containers will provide in the future.

### Commit Quality Gate
Before any commit is accepted, the following checks run in sequence (fail-fast):
1. **Path check** — all staged files must be under `src/` or `lib/`
2. **Formatting** — `cargo fmt --check` must pass
3. **No stubs** — no `todo!()`, `unimplemented!()`, `TODO`, `FIXME` markers in committed code
4. **Clippy** — `cargo clippy -- -D warnings` must pass
5. **Tests** — `cargo test` must pass (all tests, including the tester's tests, must be green)

If any check fails, the commit is rejected with a structured error message. Fix the issue and try again.

---
