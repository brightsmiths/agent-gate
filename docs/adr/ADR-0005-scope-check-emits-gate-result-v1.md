# ADR-0005: The scope check emits gate-warden's `gate-result/v1`

**Status:** Proposed
**Date:** 2026-11-27

## Context

gate-warden runs `scope-check` as a `native` check, so agent-gate writes the gate result itself.
Two specifications define a gate result format, and both are still proposed:

- **gate-warden** defines `gate-result/v1`:
  - JSON, written to `$GATE_RESULT_FILE`;
  - `format`, `check_id`, `status` (`pass` / `fail` / `error`), `findings[]` and `metrics[]`;
  - no additional properties.
- **The harness** defines `urn:brightsmiths:harness:gate-result:1`:
  - YAML-shaped;
  - statuses include `skipped` and `not-applicable`;
  - fields include `subject`, `harness` and `thresholds`.

The two formats are not compatible. gate-warden is the only consumer of check results, and it
defines the emission contract (environment variables, the file, size caps, exit-code rules).

## Decision

- The scope check emits **`gate-result/v1` as defined by gate-warden**.
- Result emission sits behind a port, so a later agreed format needs only a new adapter.
- Status mapping:
  - no violations → `pass`;
  - at least one violation → `fail`;
  - any configuration, identity-map or git error → `error`.
- Findings:
  - one per (commit, path, rule), with `location.path` and `rule` (`out-of-scope`,
    `protected-path`, `unknown-identity`, `mixed-identity`, `special-entry`, `invalid-path`);
  - a coarse `message` naming the commit's short SHA and role;
  - severity `error`.
- Findings are capped at 1000. The summary and metrics still report the true totals.
- Metrics: `scope.commits`, `scope.paths`, `scope.violations`.
- Exit codes: `0` for pass, `1` for fail, `2` for error. When run outside gate-warden, the same
  document goes to `--result-file` or stdout.

## Consequences

- agent-gate works with gate-warden L1 without any adapter.
- The format conflict between the harness and gate-warden must be resolved in those
  repositories. This is a cross-repository item (AS-08). agent-gate follows the outcome.

## Alternatives considered

- **Emit the harness format:** gate-warden would reject it as `CheckOutputInvalid`.
- **Emit both:** doubles the contract surface with no consumer for the second.
- **Use the exit code as the only signal:** gives no findings, so no useful feedback.
