# Preset reference

> **AI agents do not select presets.** In safe mode, send a `purpose` (e.g. `inventory_icon`) and Icon Forge resolves the correct preset internally. This document is for humans, contributors, and expert tooling.

Presets are reusable composition contracts — versioned production recipes with `preset_revision`. They encode intent rather than an asset-specific accident.

## Production presets (internal recipes)

| Preset | Intended use | Default output |
| --- | --- | --- |
| `inventory_item` | General item grid | 256×256 transparent |
| `weapon` | Elongated weapons | 256×256 transparent diagonal |
| `armor` | Armor/equipment pieces | 256×256 transparent three-quarter |
| `consumable` | Potions, food, scrolls | 256×256 transparent |
| `resource` | Crafting resources and gems | 256×256 transparent close framing |
| `creature_portrait` | Creature busts and heads | 256×256 gradient portrait |
| `npc_portrait` | Dialogue/shop portraits | 256×256 gradient portrait |
| `boss_portrait` | Dramatic boss portraits | 512×512 gradient portrait |
| `equipment_preview` | Detail panels | 512×512 transparent |
| `shop_thumbnail` | Small shop grids | 128×128 transparent |
| `neutral_asset_thumbnail` | Asset browser and smoke tests | 256×256 transparent |

## Purpose → preset mapping (agent view)

Agents send `purpose`; `RecipeResolver` chooses the preset from inspection morphology. Example: `inventory_icon` on an elongated 3D asset may resolve to `weapon` instead of `inventory_item`. The agent does not need to know.

## Camera (expert)

`projection` is `orthographic` or `perspective`. Camera values include yaw, pitch, roll, FOV, distance, orthographic size, target occupancy, padding, target, offset, zoom bounds, and `auto_frame`.

Per-asset sidecars may also use `camera.min_zoom` and `camera.max_zoom` for unusual world-unit scales. Sidecars are inherited by future safe-mode agent calls.

Sidecars are recursively strict: unknown nested keys (including lighting) fail with `OVERRIDE_INVALID`. Lighting is a human/maintainer correction surface, not a safe Machine API field. Allowed lighting keys are defined once in `OverrideService.LIGHTING_SCHEMA`: `rig`, `ambient_energy`, and `key`/`fill`/`rim` with `angle`, `intensity`, `color`, and `shadow`.

Orientation strategies are predictable geometric heuristics: `preserve`, `longest_axis_diagonal`, `upright`, `weapon_diagonal`, `shield_frontal`, `potion_three_quarter`, `helmet_three_quarter`, `creature_portrait`, and `character_full_body`.

## Presentation separation

The model render is composed first. Background, outline, glow, and shadow are presentation layers in the environment/post-process sections. This keeps transparent raw icons possible even when a portrait preset uses a gradient backdrop.
