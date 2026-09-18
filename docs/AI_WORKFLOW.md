# AI workflow

Icon Studio is designed to be driven by a tool-using agent rather than terminal scraping. Use `--json` for every command that will be parsed.

## Discover

```bash
./scripts/iconstudio presets --json
./scripts/iconstudio schema --json
./scripts/iconstudio explain inventory_item --json
```

The schema returns field types, enum values, valid ranges, and descriptions. The preset listing returns intended use, resolution, projection, and tags.

## Inspect, render, and correct

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

