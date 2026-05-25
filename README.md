# agentgate experiment — Enforced TDD with AI Coding Agents

## Overview

This is a soft-enforcement implementation of the agentgate concept: separating AI coding agents into **tester** and **coder** roles with path restrictions and commit quality gates.

The tester agent writes failing tests from specifications. The coder agent writes implementation code to make those tests pass. Neither can modify the other's files. A commit quality gate prevents incomplete or non-conforming code from being committed.

This works with both **VS Code Copilot** and **Claude Code**, sharing the same body content with platform-specific frontmatter.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    .agentgate.toml                           │
│              (single source of truth)                        │
│                                                             │
│  modes.tester:  writable=[tests]   readonly=[src, lib]      │
│  modes.coder:   writable=[src,lib] readonly=[tests]         │
│  checks: paths → formatting → no-stubs → clippy → tests    │
└──────────┬──────────────────────────────┬───────────────────┘
           │                              │
    ┌──────▼──────┐              ┌────────▼────────┐
    │ Claude Code │              │  Git Pre-Commit  │
    │ PreToolUse  │              │     Hook         │
    │   Hooks     │              │                  │
    │             │              │  Runs full check │
    │ Denies file │              │  pipeline on     │
    │ writes      │              │  every commit    │
    │ outside     │              │                  │
    │ allowed     │              │  Backstop for    │
    │ paths       │              │  ALL agents      │
    └─────────────┘              └──────────────────┘

    ┌─────────────────────────────────────────────────────────┐
    │                  Agent Files                             │
    │                                                         │
    │  .github/agents/tester.agent.md  ← Copilot reads this  │
    │  .github/agents/coder.agent.md   ← Copilot reads this  │
    │                                                         │
    │  .claude/agents/tester.md        ← Claude Code reads    │
    │  .claude/agents/coder.md         ← Claude Code reads    │
    │                                                         │
    │  Built from:                                            │
    │    agents/frontmatter/{platform}-{role}.yml             │
    │    agents/enforcement/{role}-enforcement.md              │
    │    agents/body/{role}-body.md                            │
    └─────────────────────────────────────────────────────────┘
```

## Enforcement Layers

| Layer | Mechanism | Bypossable? | Active Now? |
|-------|-----------|-------------|-------------|
| 1. Instructions | Agent prompt says "do not write to tests/" | Yes (agent can ignore) | ✅ |
| 2. Claude Code hooks | PreToolUse hook denies file writes outside allowed paths | Hard to bypass (hook overrides permission system) | ✅ |
| 3. Git pre-commit | Rejects commits with files outside allowed paths | Bypassable with `--no-verify` | ✅ |
| 4. Docker bind mounts | Kernel-level read-only filesystem | Cannot bypass from inside container | ❌ (future: agentgate binary) |

Layers 1-3 give you practical enforcement for the experiment. Layer 4 is the agentgate binary's eventual contribution.

## File Structure

```
your-repo/
├── .agentgate.toml                    # Shared config (modes + checks)
├── .github/
│   └── agents/
│       ├── tester.agent.md            # Copilot tester agent (generated)
│       └── coder.agent.md             # Copilot coder agent (generated)
├── .claude/
│   ├── agents/
│   │   ├── tester.md                  # Claude Code tester agent (generated)
│   │   └── coder.md                   # Claude Code coder agent (generated)
│   └── hooks.json                     # Claude Code hook configuration
├── .githooks/
│   └── pre-commit                     # Git pre-commit quality gate
├── agents/                            # Source parts (not read by agents)
│   ├── frontmatter/
│   │   ├── copilot-tester.yml
│   │   ├── copilot-coder.yml
│   │   ├── claude-tester.yml
│   │   └── claude-coder.yml
│   ├── enforcement/
│   │   ├── tester-enforcement.md
│   │   └── coder-enforcement.md
│   └── body/
│       ├── tester-body.md             # ← Your existing tester chatmode content
│       └── coder-body.md              # ← Your existing coder chatmode content
├── scripts/
│   ├── build-agents.sh                # Assembles agent files from parts
│   └── agentgate-check-path.sh        # Path enforcement script
├── docs/
│   └── spec/                          # Specs (tester reads from here)
│       ├── assertions.md
│       ├── interfaces/
│       └── ...
├── src/                               # Implementation (coder writes here)
└── tests/                             # Tests (tester writes here)
```

## Setup

### 1. Copy your existing chatmode bodies

Strip the YAML frontmatter from your existing chatmode files and place the body content:

```bash
# Remove the --- frontmatter --- from each chatmode and save as body
# (manual step — extract everything below the closing --- line)
cp tester_chatmode_body.md agents/body/tester-body.md
cp coder_chatmode_body.md  agents/body/coder-body.md
```

### 2. Build the agent files

```bash
chmod +x scripts/build-agents.sh scripts/agentgate-check-path.sh
./scripts/build-agents.sh
```

This assembles:
- `.github/agents/tester.agent.md` = copilot frontmatter + enforcement preamble + body
- `.github/agents/coder.agent.md` = copilot frontmatter + enforcement preamble + body
- `.claude/agents/tester.md` = claude frontmatter + enforcement preamble + body
- `.claude/agents/coder.md` = claude frontmatter + enforcement preamble + body

### 3. Configure git hooks

```bash
chmod +x .githooks/pre-commit
git config core.hooksPath .githooks
```

### 4. Configure Claude Code hooks

The `.claude/hooks.json` file configures PreToolUse hooks for path enforcement.

> **NOTE:** Verify the hooks configuration format against the current Claude Code
> documentation. The hook system is evolving and the exact configuration format
> may differ from what's provided here. Key concepts to configure:
>
> - PreToolUse hook on Write/Edit tools
> - Hook calls `scripts/agentgate-check-path.sh` with the target file path
> - On script exit 0 → allow; on exit 1 → deny
>
> Check: https://docs.anthropic.com/en/docs/claude-code/hooks

### 5. Set the agent mode

Before starting an agent session, set the mode:

```bash
# For tester session
export AGENTGATE_MODE=tester

# For coder session
export AGENTGATE_MODE=coder

# To disable enforcement (normal development)
unset AGENTGATE_MODE
```

## Workflow

### The TDD Red/Green Cycle

```
1. Human selects a spec from docs/spec/

2. TESTER AGENT — new chat session (AGENTGATE_MODE=tester)
   ├── Reads: docs/spec/assertions.md, docs/spec/interfaces/
   ├── Writes: tests/
   ├── Cannot write: src/, lib/
   ├── Cannot read: src/ (by instruction; hard enforcement later)
   ├── Commits: test files only (pre-commit validates)
   └── Session ends. Tests are committed to disk.

3. HUMAN REVIEWS the tests
   └── Are they correct? Do they match the spec?

4. CODER AGENT — new chat session (AGENTGATE_MODE=coder)
   ├── Reads: tests/ (from disk, not from tester's context)
   ├── Reads: docs/spec/interfaces/
   ├── Writes: src/, lib/
   ├── Cannot write: tests/
   ├── Commits: implementation files only (pre-commit validates)
   │   └── All checks must pass: fmt, no-stubs, clippy, tests
   └── Session ends. Implementation is committed to disk.

5. HUMAN REVIEWS the implementation
   └── Does it satisfy the spec? Are there shortcuts?

IMPORTANT: Tester and coder sessions are NEVER shared.
Each starts fresh. Context isolation is deliberate — it simulates
the Docker container model where agents literally cannot see each
other's work-in-progress.
```

### Using with Copilot in VS Code

1. Open a **new** Chat session (don't continue from a previous agent session)
2. From the Agents dropdown, select **Tester** or **Coder**
3. The agent operates with its instructions and tool restrictions
4. When the agent finishes, **close the session**
5. Start a **new** session for the next agent in the cycle
6. The git pre-commit hook enforces quality on every commit

**Do NOT use handoffs between tester and coder.** Context isolation is deliberate.

### Using with Claude Code

1. Start Claude Code with the mode set: `AGENTGATE_MODE=tester claude`
2. Use the `/agents` command to switch to the tester or coder agent
3. The PreToolUse hooks enforce path restrictions in real-time
4. The git pre-commit hook provides the commit quality gate

## Maintenance

### Adding a new agent role

1. Create `agents/frontmatter/copilot-{role}.yml`
2. Create `agents/frontmatter/claude-{role}.yml`
3. Create `agents/enforcement/{role}-enforcement.md`
4. Create `agents/body/{role}-body.md`
5. Add the mode to `.agentgate.toml`
6. Run `./scripts/build-agents.sh {role}`

### Editing agent instructions

Edit the body file in `agents/body/`, then rebuild:

```bash
./scripts/build-agents.sh
```

Changes propagate to both platforms automatically.

### Upgrading to hard enforcement

When the agentgate Rust binary is built:

1. `.agentgate.toml` is already the correct config format — the binary reads it directly
2. `agentgate run tester` creates a Docker container with `src/` mounted read-only
3. `agentgate run coder` creates a Docker container with `tests/` mounted read-only
4. The commit gateway replaces the git pre-commit hook with an MCP tool
5. The agent files and enforcement preambles remain — they become documentation of the enforced restrictions rather than the enforcement mechanism itself

## Limitations (Soft Enforcement)

- **Copilot path restrictions are instructional only.** Copilot doesn't have a hook system that can deny file writes. The pre-commit hook is the backstop.
- **Claude Code hooks depend on correct configuration.** The hooks system is experimental and the configuration format may change.
- **`AGENTGATE_MODE` must be set manually.** There's no automatic detection of which agent role is active. This is a UX gap that the agentgate binary solves with `agentgate run <mode>`.
- **`--no-verify` bypasses the pre-commit hook.** A determined agent (or human) can skip the quality gate. The agentgate binary solves this by making git itself read-only.
- **The tester can still `cat src/*.rs` via Bash.** The instruction says not to, but soft enforcement can't prevent it. Docker bind mounts solve this by making the files invisible.
