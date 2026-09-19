# Troubleshooting

## Machine API (agents)

### `UNKNOWN_FIELD` or `EXPERT_FIELD_IN_SAFE_MODE`

You sent a field that safe mode rejects (e.g. `yaw`, `preset`, `bogus_field`). Remove it. Discover valid fields with `{"operation":"schema"}`.

### `PURPOSE_UNSUPPORTED`

The `purpose` value is not in the purpose registry. Discover valid purposes with `{"operation":"capabilities"}`.

### `PATH_NOT_ALLOWED`

Safe mode cannot write outside `generated/`. Do not specify arbitrary output paths — Icon Studio chooses the destination from `purpose`.

### `needs_review` with `FRAMING_UNRESOLVED`

Bounded auto-correction could not satisfy the production contract. Read `recommended_action` (usually `manual_composition_review`). A human may save a sidecar; your next safe-mode call should inherit it.

### `success: false` but a PNG exists

Expert/legacy renders may write before full validation. Safe-mode `render_asset` uses transactional output: validate → commit. Failed safe-mode renders do not overwrite existing valid artifacts.

### Response is not JSON

Use `./scripts/iconstudio api --request FILE --json`, not raw Godot invocation. The wrapper filters engine startup text.

## General

### `ICONSTUDIO_GODOT_NOT_FOUND`

Install Godot 4.x or set `ICONSTUDIO_GODOT=/path/to/Godot`. The local development checkout may contain a non-committed binary in `.tools/godot/`.

### `SOURCE_LOAD_FAILED` or `SOURCE_INSTANTIATE_FAILED`

Confirm the model exists, imports in Godot, and all relative dependencies are present. Use `inspect_asset` or `inspect SOURCE --json` first. Icon Studio does not invoke Blender or repair malformed model files.

### `OUTPUT_TRANSPARENT`

The scene rendered no visible pixels. Check model import/materials, source scale, and the selected preset. A sidecar can change orientation or occupancy, but cannot repair an invalid asset.

### `OUTPUT_CLIPPED`, `OUTPUT_OCCUPANCY_LOW`, or `OUTPUT_OCCUPANCY_HIGH`

In safe mode, these become `needs_review` when they violate the purpose contract. In expert mode, read `metrics` and try a sidecar or flags such as `--occupancy`, `--yaw`, `--pitch`, `--roll`, and `--scale`.

## Slow renders

Use the cache, avoid `force` for unchanged sources, and choose an appropriate supersampling value. Repeated identical API requests return `cache_hit: true`.
