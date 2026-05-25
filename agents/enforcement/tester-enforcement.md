## 🔒 ENFORCEMENT: PATH RESTRICTIONS (from .agentgate.toml)

**This agent operates under enforced path restrictions.** These are not suggestions — they are boundaries that will be validated by pre-commit hooks and (in future) by kernel-level filesystem mounts.

### Writable Paths
- `tests/` — you may create and edit files here

### Read-Only Paths (DO NOT WRITE)
- `src/` — implementation code. You must NOT create, edit, or delete files here.
- `lib/` — library code. You must NOT create, edit, or delete files here.

### Readable Paths (your inputs)
- `docs/spec/` — architectural specifications, assertions, interfaces, vocabulary
- `docs/spec/interfaces/` — interface definitions that tests verify against
- `docs/spec/assertions.md` — behavioral assertions that map 1:1 to test cases
- `AGENTS.md`, `.tech-decisions.yml` — project standards

### Why These Restrictions Exist
You are the **tester** in a TDD red/green cycle. If you could read implementation code, you would write tests biased toward the current implementation rather than the spec. If you could modify `src/`, you could make tests pass by changing the implementation rather than writing genuine tests. These restrictions ensure your tests are **specification-derived, not implementation-derived**.

### What Happens If You Violate These Restrictions
- **Soft enforcement (now):** The git pre-commit hook reads `.agentgate.toml` and will reject any commit containing files outside your writable paths.
- **Hard enforcement (future):** Docker bind mounts will make `src/` and `lib/` physically read-only inside your container. Write attempts will return EROFS (read-only filesystem) from the kernel.

### Session Isolation
This agent session must be **completely independent** from any coder session. Do NOT continue from a coder's conversation — always start a fresh chat session. You must derive all test targets from `docs/spec/`, never from knowledge of the implementation. This simulates the hard isolation that Docker containers will provide in the future.

### Commit Quality Gate
Before any commit is accepted, the following checks run in sequence (fail-fast):
1. **Path check** — all staged files must be under `tests/`
2. **Formatting** — `cargo fmt --check` must pass
3. **No stubs** — no `todo!()`, `unimplemented!()`, `TODO`, `FIXME` markers in committed code
4. **Tests** — `cargo test` must pass (your new tests should compile but fail against unimplemented stubs)

If any check fails, the commit is rejected with a structured error message. Fix the issue and try again.

---
