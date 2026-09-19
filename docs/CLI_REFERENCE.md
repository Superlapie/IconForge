# CLI reference

> **AI agents:** use the [Machine API](MACHINE_API.md), not raw CLI commands. This reference documents the `iconstudio` transport layer.

All commands are available through `./scripts/iconstudio`. Add `--json` to receive one machine-readable object. Exit codes:

- `0`: success.
- `2`: invalid command, argument, source, preset, or input JSON.
- `3`: render or output quality failure.
- `4`: batch had both successes and failures (or `needs_review` / `partial_success` from API).
- `127`: Godot executable was not found by the wrapper.

## Machine API (primary interface for agents)

```bash
./scripts/iconstudio api --request request.json --json
```

Safe-mode agents send semantic requests (`purpose`, not `yaw`/`fov`). Expert mode: add `--expert`.

| Operation | Purpose |
|-----------|---------|
| `capabilities` | Discover operations, purposes, extensions |
| `schema` | Executable field definitions and error codes |
| `render_asset` | Single validated production render |
| `render_asset_set` | Multiple purposes from one source |
| `inspect_asset` | Deterministic source inspection |
| `validate_output` | Validate existing PNG against purpose contract |
| `explain_result` | Audit trace from job ID or manifest |

See [MACHINE_API.md](MACHINE_API.md) and [AGENTS.md](../AGENTS.md).

## Legacy / expert commands (humans and debugging)

```text
inspect SOURCE [--json]
preview SOURCE --preset ID [--output PATH] [overrides]
render SOURCE_OR_DIRECTORY --preset ID --output PATH [--force] [overrides]
render-batch INPUT --preset ID --output DIRECTORY [--manifest PATH] [--force]
presets
create-preset ID [--from BASE_ID] [--output PATH]
validate-preset PRESET.json
explain PRESET_ID
schema
compare FIRST.png SECOND.png
validate-output IMAGE.png [--preset ID] [--occupancy FLOAT]
```

**Do not teach normal agents to use these.** They expose renderer internals that safe mode deliberately hides.

## Common render flags (expert only)

`--preset`, `--output`, `--force`, `--override`, `--width`, `--height`, `--yaw`, `--pitch`, `--roll`, `--occupancy`, `--padding`, `--scale`, `--vertical-offset`, `--horizontal-offset`, and `--background`.

## Examples

**Agent (recommended):**

```bash
./scripts/iconstudio api --request examples/render_inventory.json --json
```

**Expert:**

```bash
./scripts/iconstudio inspect fixtures/sword.gltf --json
./scripts/iconstudio render fixtures/sword.gltf --preset weapon --output out/sword.png --json
```
