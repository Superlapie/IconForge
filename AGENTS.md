# Icon Studio agent guide

> **This repository is built for you.** Icon Studio is an AI-agent-first content service. If you are an autonomous agent, coding assistant, or Enigma pipeline worker, this file is your primary integration contract. Read it before calling any render command.

## What this tool does

Icon Studio converts GLB/glTF models and static images into consistent PNG game imagery. You specify **semantic intent** (`purpose`); Icon Studio owns inspection, recipe resolution, rendering, bounded correction, validation, and commit.

**Philosophy:** Agents specify intent. Icon Studio owns rendering.

## Expected AI workflow

**Use the semantic machine API** ([docs/MACHINE_API.md](docs/MACHINE_API.md)). Never guess camera, lighting, or output paths in normal operation.

1. Discover with `{"operation":"capabilities"}` or `{"operation":"schema"}`:
   ```bash
   ./scripts/iconstudio api --request request.json --json
   ```
2. Render with:
   ```json
   {"schema_version":1,"operation":"render_asset","asset":"...","purpose":"inventory_icon"}
   ```
3. Read `status`, `recipe`, `quality`, `manifest`, and `recommended_action` on failure.
4. For multiple outputs from one source, use `render_asset_set` with an `outputs` array.
5. Human corrections live in `<source_basename>.icon.json` sidecars; your future safe-mode calls inherit them automatically.

**Do not** use legacy expert CLI commands (`render --preset weapon --yaw 18`) unless explicitly authorized for debugging.

Machine workflows must use `--json`. Every response is one JSON object with stable error codes. Human terminal text is for interactive use only.

## What you should send

| Field | Example | Required |
|-------|---------|----------|
| `schema_version` | `1` | yes |
| `operation` | `render_asset` | yes |
| `asset` | `assets/items/sword.glb` | yes |
| `purpose` | `inventory_icon` | yes (for render) |

## What you should NOT send (safe mode)

- `yaw`, `pitch`, `roll`, `fov`, `occupancy`, `padding`, `scale`
- `preset` IDs (resolved internally from `purpose` + inspection)
- Arbitrary `output` paths (destination chosen by purpose registry)
- Unknown fields (rejected with `UNKNOWN_FIELD`)

## Outcomes you can receive

| Status | Meaning | Your action |
|--------|---------|-------------|
| `validated` | Output passed production contract | Use `output.path` and `manifest` |
| `needs_review` | Bounded correction exhausted | Read `recommended_action`; human may fix sidecar |
| `failed` | Hard error (bad request, missing source) | Read `code` and `recommended_action` |
| `partial_success` | `render_asset_set` with mixed results | Inspect per-purpose entries in `outputs` |

## Preset model (internal — do not select in safe mode)

Presets are versioned production recipes in `presets/` with `preset_revision`. The `RecipeResolver` maps your `purpose` plus inspection morphology to the correct preset. You do not need to know whether a sword becomes `weapon` or `inventory_item`.

Built-in preset families include `inventory_item`, `weapon`, `armor`, `consumable`, `resource`, `creature_portrait`, `npc_portrait`, `boss_portrait`, `equipment_preview`, `shop_thumbnail`, and `neutral_asset_thumbnail`.

## Override model (sidecars)

Per-asset sidecars use the source basename (`iron_sword.icon.json`). They are loaded automatically during safe-mode renders. If a human fixed framing, your next identical request should succeed without knowing the correction details.

## Validation and quality rules

`success: true` means the output passed the **production contract** — not merely that a PNG was written. Quality checks cover resolution, alpha, clipping, occupancy bounds, and empty silhouettes. Auto-framing has a bounded correction loop and never retries forever.

## Batch processing

For multiple purposes on one asset, prefer `render_asset_set` over multiple `render_asset` calls. For many sources with one preset, legacy `render-batch` remains available for expert workflows.

## Safe editing rules (if you modify this repo)

- Never overwrite a source model or source image.
- Keep canonical preset fields in JSON and shared behavior in `core/` services.
- Do not bypass `ApiService`, `RenderService`, `PresetDefinition`, `AssetInspector`, or `QualityService`.
- Do not add proprietary fixtures or online runtime dependencies.
- Run `./scripts/quality-gate` after changes to rendering, presets, CLI, fixtures, API, or output validation.

## Canonical quality command

```bash
./scripts/quality-gate
```
