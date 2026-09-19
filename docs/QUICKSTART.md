# Quickstart

## For AI agents (start here)

Icon Forge is built for autonomous agents. Use the semantic machine API:

```bash
./scripts/iconforge api --request examples/render_inventory.json --json
```

```json
{
  "schema_version": 1,
  "operation": "render_asset",
  "asset": "fixtures/sword.gltf",
  "purpose": "inventory_icon"
}
```

Discover supported operations and purposes:

```bash
./scripts/iconforge api --request <(printf '%s' '{"schema_version":1,"operation":"capabilities"}') --json
```

Read [AGENTS.md](../AGENTS.md) and [MACHINE_API.md](MACHINE_API.md) for the full contract.

## For humans: GUI

```bash
./scripts/launch-gui
```

Drop a `.glb`, `.gltf`, `.png`, `.jpg`, or `.webp` into the source panel, choose a preset, orbit or zoom the preview, and export a PNG.

## For experts: legacy CLI

### Inspect a source

```bash
./scripts/iconforge inspect fixtures/sword.gltf --json
```

### Render one source

```bash
./scripts/iconforge render fixtures/sword.gltf \
  --preset weapon \
  --output out/sword.png \
  --force \
  --json
```

### Render a directory

```bash
./scripts/iconforge render-batch fixtures \
  --preset neutral_asset_thumbnail \
  --output out/icons \
  --manifest out/icons/manifest.json \
  --json
```

## Quality gate

```bash
./scripts/quality-gate
```

Includes machine API smoke tests and adversarial request validation.
