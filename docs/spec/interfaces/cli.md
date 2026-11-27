# Interface: command line

One binary, `agent-gate`. Every command is stateless and offline.

## Commands

### `validate` (L1)

```text
agent-gate validate --roles <file> [--identities <file>]
```

Validates the policy, and the identity map against it if one is given. Diagnostics go to stderr.

### `mount-plan` (L1)

```text
agent-gate mount-plan --roles <file> --role <role> --checkout <dir>
                      [--writable-paths <glob>...] [--output <file>]
```

Writes a `mount-plan:1` document ([mount-plan.md](mount-plan.md)) to `--output` or stdout.

### `scope-check` (L1)

```text
agent-gate scope-check [--roles <file>] (--identities <file> | --as-role <role>)
                       [--range <base>..<head>] [--repo <dir>]
                       [--check-id <id>] [--result-file <file>]
```

Writes a `gate-result/v1` document ([scope-check-result.md](scope-check-result.md)).

- `--as-role` is pre-push mode, for sandbox-runner. It cannot be combined with `--identities`,
  and it is refused in gate-warden mode.
- `--repo` defaults to the current directory, or to `GATE_WORKSPACE` in gate-warden mode.

### `check-path` (L2, planned)

```text
agent-gate check-path --roles <file> --role <role> <path>...
```

Prints each path's access. It exits `1` if any path is not W.

## gate-warden mode

gate-warden mode is active when `GATE_RESULT_FILE` is set. Omitted arguments are then taken from
the environment:

| Argument | Source |
| --- | --- |
| `--range` | `GATE_BASE_SHA..GATE_HEAD_SHA` |
| `--repo` | `GATE_WORKSPACE` |
| `--check-id` | `GATE_CHECK_ID` |
| `--result-file` | `GATE_RESULT_FILE` |
| `--roles` | `$GATE_HARNESS_DIR/disciplines/<pin.discipline>/roles.yaml`, where the pin is `$GATE_DEFAULT_BRANCH_DIR/.factory/pin.yaml` |
| `--identities` | `$GATE_DEFAULT_BRANCH_DIR/.factory/identities.yaml` |

Rules:

- Explicit `--roles` and `--identities` paths are allowed only if they resolve outside
  `GATE_WORKSPACE` (AG-REQ-061).
- If a required variable is missing, the result is `EnvironmentIncomplete` and status `error`.

So the harness gate definition needs no path arguments:

```yaml
- id: scope-check
  run: ["agent-gate", "scope-check"]
  adapter: native
```

## Exit codes

| Code | `validate` | `mount-plan` | `scope-check` |
| --- | --- | --- | --- |
| `0` | valid | plan written | `pass` |
| `1` | — | — | `fail` |
| `2` | invalid input, usage error or other error | error or usage error; no plan written | `error` (also for usage errors; written if a destination is known) |

## Output discipline

- Machine output goes to stdout or the given file. Human diagnostics go to stderr.
- Output never depends on locale, terminal or time.
