# Troubleshooting

## `ICONSTUDIO_GODOT_NOT_FOUND`

Install Godot 4.x or set `ICONSTUDIO_GODOT=/path/to/Godot`. The local development checkout may contain a non-committed binary in `.tools/godot/`.

## `SOURCE_LOAD_FAILED` or `SOURCE_INSTANTIATE_FAILED`

Confirm the model exists, imports in Godot, and all relative dependencies are present. Use `inspect SOURCE --json` first. Icon Studio does not invoke Blender or repair malformed model files.

## `OUTPUT_TRANSPARENT`

The scene rendered no visible pixels. Check model import/materials, source scale, and the selected preset. A sidecar can change orientation or occupancy, but cannot repair an invalid asset.

## `OUTPUT_CLIPPED`, `OUTPUT_OCCUPANCY_LOW`, or `OUTPUT_OCCUPANCY_HIGH`

Read `metrics` from the render result. Try a sidecar or one-shot flags such as `--occupancy`, `--yaw`, `--pitch`, `--roll`, and `--scale`. Auto-framing performs at most five bounded correction passes.

## CLI JSON contains engine logs

Use the repository wrapper and `--json`, not a raw Godot invocation. The wrapper filters normal engine startup text so the command’s stdout is one JSON object.

## Slow renders

Use the cache, avoid `--force` for unchanged sources, and choose an appropriate supersampling value. Large portrait presets intentionally render more pixels before downsampling.

