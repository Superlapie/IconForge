# AI workflow

Icon Studio is designed to be driven by a tool-using agent rather than terminal scraping. **Normal agents should use the semantic machine API** — see [MACHINE_API.md](MACHINE_API.md).

## Recommended: semantic machine API

```bash
echo '{"schema_version":1,"operation":"capabilities"}' | ./scripts/iconstudio api --stdin --json
./scripts/iconstudio api --request examples/render_inventory.json --json
```

```json
{
  "schema_version": 1,
  "operation": "render_asset",
  "asset": "fixtures/sword.gltf",
  "purpose": "inventory_icon"
}
```

Agents specify **purpose**, not camera/lighting/FOV. Icon Studio inspects, resolves the recipe, renders, validates, and commits.

## Discover

```bash
echo '{"schema_version":1,"operation":"schema"}' | ./scripts/iconstudio api --stdin --json
./scripts/iconstudio presets --json
```

## Expert / legacy CLI (debugging and humans)

```bash
./scripts/iconstudio inspect assets/iron_sword.glb --json
./scripts/iconstudio render assets/iron_sword.glb --preset weapon --output out/iron_sword.png --force --json
./scripts/iconstudio validate-output out/iron_sword.png --preset weapon --json
```

If the render reports `OUTPUT_OCCUPANCY_LOW`, `OUTPUT_OCCUPANCY_HIGH`, or `OUTPUT_CLIPPED`, apply a bounded override:

```bash
./scripts/iconstudio render assets/iron_sword.glb \
  --preset weapon \
  --occupancy 0.86 \
  --yaw 18 \
  --roll -32 \
  --output out/iron_sword.png \
  --force --json
```

For a durable correction, save a sidecar named `iron_sword.icon.json`. The next batch run loads it automatically. The GUI’s “Save sidecar” button writes the same format.

## Batch and manifest

```bash
./scripts/iconstudio render-batch assets/items \
  --preset inventory_item \
  --output generated/icons \
  --manifest generated/icons/manifest.json \
  --json
```

The command continues after individual failures. Treat `success: false` with `partial_success: true` as a completed-but-actionable batch; inspect failed entries in `renders` and the manifest.

## Determinism and cache

The cache is keyed by source hash, resolved preset JSON, overrides, and tool version. Use `--force` after intentionally changing external dependencies or when auditing a fresh output. Do not manually edit cache entries.

