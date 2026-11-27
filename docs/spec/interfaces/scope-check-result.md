# Interface: scope-check result

**Format:** gate-warden `gate-result/v1` (`format: "gate-result/v1"`), as defined in
[brightsmiths/gate-warden](https://github.com/brightsmiths/gate-warden)
`docs/spec/interfaces/gate-result-format.md` and `schemas/gate-result/v1.schema.json`.
**Decision record:** [ADR-0005](../../adr/ADR-0005-scope-check-emits-gate-result-v1.md).

agent-gate is a **native** check: it writes the result itself.

## Destination

| Mode | Destination |
| --- | --- |
| gate-warden mode (`GATE_RESULT_FILE` set) | `GATE_RESULT_FILE` |
| `--result-file <path>` | That file |
| Otherwise | stdout. Diagnostics go to stderr only |

## Field mapping

| `gate-result/v1` field | Value |
| --- | --- |
| `format` | `"gate-result/v1"` |
| `check_id` | `GATE_CHECK_ID`, else `--check-id`, else `"scope-check"` |
| `status` | `pass` (no violations), `fail` (at least one violation), `error` (any error) |
| `summary` | For example `"3 out-of-scope paths in 2 of 5 commits"` or `"policy invalid: unknown field 'writes' in role builder"`. At most 500 characters |
| `findings[]` | One per violation, in the order of AG-REQ-047. At most 1000 |
| `findings[].location.path` | The violating path, when the rule has one and it is valid UTF-8. Omitted for identity rules and `invalid-path` |
| `findings[].rule` | `out-of-scope`, `protected-path`, `unknown-identity`, `mixed-identity`, `special-entry`, `invalid-path` |
| `findings[].severity` | `error` |
| `findings[].message` | `"<short-sha> (<role>): <rule text>"`, e.g. `"3f9a2c1 (builder): path is not writable by this role"`. Never file contents. Identity rules name the commit, not the email |
| `metrics[]` | `scope.commits`, `scope.paths`, `scope.violations` (unit `count`) |
| `tool` | `{ "name": "agent-gate", "version": "<semver>" }` |

Findings never include `req_id` or `visibility: holdout`. Scope violations are not holdout
content.

## Exit codes

| Exit | Meaning | gate-warden recording |
| --- | --- | --- |
| `0` | `pass` written | `pass` |
| `1` | `fail` written | `fail` |
| `2` | `error` written, or no result could be written | `error` |

agent-gate never exits `0` with a non-`pass` result, and never exits non-zero with `pass`.

## Size

The document is kept at or below 1 MiB (AG-REQ-062). Messages are truncated before the finding
count is capped.

## Example

```json
{
  "format": "gate-result/v1",
  "check_id": "scope-check",
  "status": "fail",
  "summary": "2 violations in 1 of 4 commits",
  "findings": [
    {
      "location": { "path": "src/billing/invoice_tests.rs" },
      "rule": "out-of-scope",
      "severity": "error",
      "message": "3f9a2c1 (builder): path is not writable by this role"
    },
    {
      "location": { "path": ".factory/identities.yaml" },
      "rule": "protected-path",
      "severity": "error",
      "message": "3f9a2c1 (builder): path is protected"
    }
  ],
  "metrics": [
    { "name": "scope.commits", "value": 4, "unit": "count" },
    { "name": "scope.paths", "value": 17, "unit": "count" },
    { "name": "scope.violations", "value": 2, "unit": "count" }
  ],
  "tool": { "name": "agent-gate", "version": "0.1.0" }
}
```
