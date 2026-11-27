# ADR-0001: Rust library plus a stateless CLI; no daemon

**Status:** Proposed
**Date:** 2026-11-27

## Context

The experiment ran as shell scripts and agent-side hooks on a developer machine. The factory
needs agent-gate as a component with two consumers:

- sandbox-runner, which needs a mount plan before it boots an agent's microVM and runs a scope
  pre-check before it pushes;
- gate-warden, which runs the authoritative scope check as a gate check command inside a clean
  microVM. That microVM has no network except the dependency proxy and no secrets.

Brightsmiths services are often long-running processes that react to webhooks. agent-gate's work
is a pure function of its inputs: policy, checkout or commit range, and identity map. It
produces no GitHub state of its own.

## Decision

- agent-gate is a **Rust library crate** plus a **CLI binary** that is a thin shell over it.
- It has **no daemon, no network access and no persistent state.** Every invocation reads its
  inputs, computes, writes its output and exits.
- sandbox-runner may link the library or call the CLI. gate-warden calls the CLI as a check
  command.
- Outputs are byte-for-byte deterministic for the same inputs.

## Consequences

- gate-warden recomputes the verdict in its own sandbox without trusting any agent-gate
  instance. This keeps the "no self-certification" principle.
- No deployment, scaling, secrets or uptime concerns. Distribution is a versioned binary
  included in the gate and sandbox-runner images.
- Consumers must pin an agent-gate version. A policy-semantics change is a versioned release.

## Alternatives considered

- **A networked service (HTTP or NATS):** it would add an attack surface to a security boundary
  and need credentials. gate-warden would also have to trust a remote verdict instead of
  recomputing it in its clean sandbox.
- **Keep shell scripts:** not portable, hard to test, and they cannot parse git objects safely.
- **Library only:** gate-warden runs checks as argv commands, so it needs a CLI.
