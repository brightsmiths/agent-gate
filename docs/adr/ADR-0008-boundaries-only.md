# ADR-0008: agent-gate is about boundaries only; agent hooks are optional

**Status:** Proposed
**Date:** 2026-11-27

## Context

The experiment combined path boundaries with a check pipeline (formatting, no-stubs, clippy,
tests) in one policy file and a git pre-commit hook. It enforced through agent-side hooks
(Claude Code `PreToolUse`, generated Copilot and Claude agent files). In the factory:

- commit-gate and gate-warden own quality checks;
- enforcement rests on the scope check run by gate-warden, which is authoritative, and on
  sandbox mount plans;
- agent-side hooks run inside the agent process and are defence in depth at most.

## Decision

- agent-gate implements **path boundaries only**. It never runs formatting, linting, stub,
  build or test checks. The experiment's check pipeline is not carried forward, so the L2
  hand-off to commit-gate and gate-warden is satisfied by design.
- The experiment's agent-file and hook generation is not carried forward at L1. At L2, an
  **optional** `check-path` command and hook-configuration output may be added for human-led
  use. They are documented as feedback only and never as the enforcement path.

## Consequences

- The policy file contains only roles and paths, which matches the harness roles schema.
- People using agents locally with hooks get fast feedback from the same policy, but nothing
  relies on those hooks.

## Alternatives considered

- **Keep a check pipeline in agent-gate:** it would duplicate commit-gate and blur the purpose.
- **Drop hook support entirely:** it is useful for human-led work and cheap once `check-path`
  exists.
