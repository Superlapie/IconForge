# Batch rendering

Batch rendering discovers supported sources recursively (`.glb`, `.gltf`, `.png`, `.jpg`, `.jpeg`, `.webp`), processes them independently, and continues after a source failure.

```bash
./scripts/iconstudio render-batch ./items \
  --preset inventory_item \
  --output ./generated/icons \
  --manifest ./generated/icons/manifest.json \
  --json
```

The output name pattern comes from the preset. Supported substitutions are `{source_name}`, `{preset}`, `{id}`, and `{extension}`. Duplicate output names receive `_2`, `_3`, and so on. Existing outputs are reused only when the cache key matches; use `--force` to replace them.

The batch result includes `summary.total`, `summary.success`, `summary.failed`, `partial_success`, and one render record per source. A failed record carries a stable error code and does not stop later assets.

## Performance behavior

The current implementation prioritizes correct resource lifetime and deterministic scene setup. Each 3D frame uses a temporary viewport and is freed after capture; it does not retain rendered images in a batch-wide array. Cache lookup avoids repeated work for unchanged sources. Parallel rendering is intentionally not enabled yet because shared Godot import/render state can make it less reliable than sequential processing.

