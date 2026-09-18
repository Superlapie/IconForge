# Icon Studio agent guide

## What this tool does

Icon Studio converts GLB/glTF models and static images into consistent PNG game imagery. The authoritative render path is the shared `RenderService`; both `app/studio_ui.gd` and `cli/cli_app.gd` call that service. Do not create a second GUI-only renderer or edit Godot scene files for individual assets.

## Expected AI workflow

1. Discover intent with `./scripts/iconstudio presets --json`.
2. Inspect the source with `./scripts/iconstudio inspect SOURCE --json`.
3. Render with a named preset and explicit output path.
4. Read the returned `metrics`, `warnings`, `errors`, and `render_passes`.
5. If framing needs correction, rerender with structured flags or write a source sidecar such as `iron_sword.icon.json`.
6. Run `validate-output` and keep the output manifest from batch work.

Machine workflows must use `--json`. JSON is one object per command and contains stable error codes. Human terminal text is only for interactive use.

## Preset model

Presets are JSON files in `presets/` with `schema_version: 1`, stable filename-safe `id`, resolution, projection, camera, lighting, environment, shadows, post-process, composition, and output sections. `PresetDefinition` is the canonical parser/normalizer. Use `validate-preset` before adding or changing a preset. Use `schema --json` instead of guessing field names.

Built-in presets include `inventory_item`, `weapon`, `armor`, `consumable`, `resource`, `creature_portrait`, `npc_portrait`, `boss_portrait`, `equipment_preview`, `shop_thumbnail`, and `neutral_asset_thumbnail`.

## Override model

Per-asset sidecars use the source basename:

```json
{
  "yaw": 18,
  "pitch": -6,
  "roll": -28,
  "occupancy": 0.84,
  "padding": 0.08,
  "scale": 0.96
}
```

The renderer automatically loads `<source_basename>.icon.json`. CLI flags override sidecar values for one invocation. Sidecars are the reproducible place to keep a correction that should apply to every future batch.

## Validation and quality rules

Quality checks detect missing outputs, invalid image data, resolution mismatch, fully transparent images, clipping, and materially low/high silhouette occupancy. `success: false` means an error blocked acceptance; warnings are actionable but do not necessarily fail a render. Auto-framing has a bounded five-pass correction loop and never retries forever.

The GUI drop boundary is `Window.files_dropped`; accepted files must flow
through `handle_dropped_files`, `AssetInspector`, and `RenderService`. Run
`./scripts/gui-e2e` for the real external-model GUI proof. On Linux/X11, run
`docs/GUI_E2E.md`'s native XDND command when validating the OS protocol itself.

## Batch processing

Use `render-batch INPUT --preset ID --output DIRECTORY --json`. One source failure is recorded in the result and manifest while other sources continue. The manifest includes tool version, preset, source, output, status, warnings, errors, and metrics. Cache keys include source SHA-256, resolved preset, override configuration, and tool version; use `--force` to bypass it.

## Safe editing rules

- Never overwrite a source model or source image.
- Prefer `apply_patch` for repository edits.
- Keep canonical preset fields in JSON and shared behavior in `core/` services.
- Do not bypass `RenderService`, `PresetDefinition`, `AssetInspector`, or `QualityService` for a new CLI or GUI feature.
- Do not add proprietary fixtures or online runtime dependencies.
- Use atomic JSON and PNG writes already provided by `IconStudioFileUtil`.
- Run `./scripts/quality-gate` after changes to rendering, presets, CLI, fixtures, or output validation.

## Adding a preset

Copy an existing JSON preset, change its stable `id`, intended-use description, and composition values, then run:

```bash
./scripts/iconstudio validate-preset presets/my_preset.json --json
./scripts/iconstudio presets --json
```

No code change is needed for a data-only preset. If a new behavior is required, extend the shared service and schema first, then add tests and documentation.

## Canonical quality command

```bash
./scripts/quality-gate
```
