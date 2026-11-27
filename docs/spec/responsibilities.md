# Responsibilities

CRC-style cards: what each component knows and does, and who it collaborates with.

## Policy model

- **Knows:**
  - the supported schema majors;
  - the reserved role `human`;
  - the protected floor `.factory/**`;
  - the validated roles, zones, path sets and compiled globs;
  - the policy source and digest.
- **Does:**
  - validates raw documents strictly;
  - expands `@name` references;
  - rejects invalid globs.
- **Collaborators:** `PolicySource` (raw bytes), glob compiler.
- **Roles:** single source of truth for "who may write where" in one evaluation.

## Path classifier

- **Knows:** the precedence rule; the glob semantics.
- **Does:**
  - classifies (role, path) as W, R or A;
  - applies narrowing;
  - answers whether a directory could contain W or R paths.
- **Collaborators:** Policy model.
- **Roles:** the only place access is decided. The mount planner and the scope evaluator both
  delegate here, so a plan and a check can never disagree.

## Mount planner

- **Knows:** the mount plan v1 shape and the directory access rules.
- **Does:**
  - turns checkout entries into sorted plan entries;
  - collapses absent subtrees;
  - records provenance;
  - refuses `human` and unknown roles.
- **Collaborators:** Path classifier, `CheckoutReader`, `ResultSink`.
- **Roles:** producer of the mount plan for sandbox-runner.

## Identity resolver

- **Knows:** the identity map and the pass-through committers.
- **Does:**
  - maps the author to a role;
  - checks the committer;
  - reports `unknown-identity` and `mixed-identity`.
- **Collaborators:** `IdentitySource`, Policy model (to check that mapped roles exist).
- **Roles:** attribution of commits to roles.

## Scope evaluator

- **Knows:** the violation rules and their order.
- **Does:**
  - for each commit, gets the role (resolver or fixed role) and its changed entries;
  - classifies each path;
  - detects special entries and invalid paths;
  - collects every violation.
- **Collaborators:** Identity resolver, Path classifier, `CommitRangeReader`.
- **Roles:** produces the `ScopeReport`. It decides nothing about the PR.

## Report mapper

- **Knows:** the `gate-result/v1` field rules, caps and size limit.
- **Does:**
  - maps a report or an error to a status, summary, findings and metrics;
  - truncates and caps.
- **Collaborators:** `ResultSink`.
- **Roles:** translator to gate-warden's contract.

## CLI

- **Knows:** commands, arguments, gate-warden mode variables and exit codes.
- **Does:**
  - parses arguments;
  - resolves inputs from the environment;
  - enforces trusted-location rules;
  - wires adapters to the business logic;
  - sets the exit code.
- **Collaborators:** all ports and adapters, `Environment`.
- **Roles:** thin shell. It contains no policy logic.

## Git reader adapter

- **Knows:** how to read commits, parents and tree diffs from the object database.
- **Does:**
  - resolves IDs;
  - checks ancestry;
  - walks the range in topological order;
  - computes changed entries (and combined changes for merges);
  - enforces caps.
- **Collaborators:** git library.
- **Roles:** the only component that touches git data. It never executes anything.

## File system walker adapter

- **Knows:** how to enumerate a directory tree without following symlinks.
- **Does:** yields raw paths and kinds, skips `.git/`, enforces the entry cap.
- **Collaborators:** OS file system.
- **Roles:** the only component that reads the checkout.
