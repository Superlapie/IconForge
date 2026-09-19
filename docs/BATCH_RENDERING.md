# Batch rendering

> **AI agents:** for multiple purposes on one asset, use `render_asset_set` via the [Machine API](MACHINE_API.md). This document covers the legacy expert `render-batch` command.

## Machine API: `render_asset_set` (recommended for agents)

```json
{
  "schema_version": 1,
  "operation": "render_asset_set",
  "asset": "assets/items/runic_sword.glb",
  "outputs": ["inventory_icon", "shop_thumbnail", "equipment_preview"]
}
```

Icon Forge inspects the source once, resolves each recipe, renders independently, validates each output, and returns one aggregate result. Valid outputs are preserved even if a sibling fails (`partial_success`).

## Legacy expert: `render-batch`

Batch rendering discovers supported sources recursively (`.glb`, `.gltf`, `.png`, `.jpg`, `.jpeg`, `.webp`), processes them independently, and continues after a source failure.

```bash
./scripts/iconforge render-batch ./items \
  --preset inventory_item \
  --output ./generated/icons \
  --manifest ./generated/icons/manifest.json \
  --json
```

The output name pattern comes from the preset. Supported substitutions are `{source_name}`, `{preset}`, `{id}`, and `{extension}`. Duplicate output names receive `_2`, `_3`, and so on. Existing outputs are reused only when the cache key matches; use `--force` to replace them.

The batch result includes `summary.total`, `summary.success`, `summary.failed`, `partial_success`, and one render record per source. A failed record carries a stable error code and does not stop later assets.

## Performance behavior

The current implementation prioritizes correct resource lifetime and deterministic scene setup. Each 3D frame uses a temporary viewport and is freed after capture. Cache lookup avoids repeated work for unchanged sources.
