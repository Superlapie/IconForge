# CLI reference

All commands are available through `./scripts/iconstudio`. Add `--json` to receive one machine-readable object. Exit codes:

- `0`: success.
- `2`: invalid command, argument, source, preset, or input JSON.
- `3`: render or output quality failure.
- `4`: batch had both successes and failures.
- `127`: Godot executable was not found by the wrapper.

## Machine API (recommended for agents)

```bash
./scripts/iconstudio api --request request.json --json
```

See [MACHINE_API.md](MACHINE_API.md). Safe-mode agents send semantic requests (`purpose`, not `yaw`/`fov`). Expert mode: add `--expert`.

## Legacy / expert commands

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

## Common render flags

`--preset`, `--output`, `--force`, `--override`, `--width`, `--height`, `--yaw`, `--pitch`, `--roll`, `--occupancy`, `--padding`, `--scale`, `--vertical-offset`, `--horizontal-offset`, and `--background`.

Supported background values are `transparent`, `solid`, and `gradient`. Output format is currently PNG.

## Examples

```bash
./scripts/iconstudio inspect fixtures/sword.gltf --json
./scripts/iconstudio render fixtures/sword.gltf --preset weapon --output out/sword.png --json
./scripts/iconstudio presets --json
./scripts/iconstudio validate-preset presets/weapon.json --json
./scripts/iconstudio schema --json
./scripts/iconstudio compare out/a.png out/b.png --json
```

