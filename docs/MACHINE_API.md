# Machine API

> **Primary interface for AI agents.** Autonomous agents integrate through this API — not by scraping terminal output or guessing renderer parameters.

## Source path resolution

Relative `asset` paths resolve **only** under `--workspace-root` / `ICONFORGE_WORKSPACE_ROOT` (the repository itself when unset). They never fall back into the Icon Forge checkout.

| `asset` value | Resolves to |
|---------------|-------------|
| `assets/items/sword.glb` | `<workspace_root>/assets/items/sword.glb` |
| `res://fixtures/sword.gltf` | Icon Forge repository resource |
| `/absolute/path/model.glb` | Explicit absolute path |

If the workspace-relative file does not exist, the API returns `SOURCE_NOT_FOUND`. Use `res://` when you intentionally want a tool-repository fixture.

## Transport

```bash
./scripts/iconforge api --request request.json --json
```

Optional workspace (recommended for Enigma):

```bash
export ICONFORGE_WORKSPACE_ROOT=/path/to/enigma
./scripts/iconforge api --workspace-root "$ICONFORGE_WORKSPACE_ROOT" --request request.json --json
```

Official Python wrapper: [examples/enigma_client.py](../examples/enigma_client.py) (uses temporary request files, not stdin; default subprocess timeout 300s).

JSON mode always returns one JSON object. If Godot fails before the API emits a response, the launcher returns `RUNTIME_START_FAILED` with `recommended_action: check_runtime_installation`.

## Agent decision algorithm

| `status` | Your action |
|----------|-------------|
| `validated` | Consume `output.path` and `manifest` |
| `partial_success` | Consume only children with `status: validated`; surface the rest |
| `needs_review` | **Stop.** Do not guess overrides or switch to expert mode |
| `failed` | Follow `recommended_action`; fix request/source only |

## Minimal render

```json
{
  "schema_version": 1,
  "operation": "render_asset",
  "asset": "fixtures/sword.gltf",
  "purpose": "inventory_icon"
}
```

## render_asset_set

The API inspects the source once per `render_asset_set` call and reuses that inspection for recipe resolution and rendering (RenderService does not re-inspect when precomputed inspection is supplied). Returns an aggregate `job_id`, `manifest`, and per-purpose entries in `outputs`.

```json
{
  "schema_version": 1,
  "operation": "render_asset_set",
  "asset": "fixtures/sword.gltf",
  "outputs": ["inventory_icon", "shop_thumbnail", "equipment_preview"]
}
```

Aggregate status rules:

- all `validated` → `validated` **and** the aggregate manifest was committed
- at least one `validated` plus any non-validated → `partial_success` **and** the aggregate manifest was committed
- zero `validated`, all `needs_review` → `needs_review`
- zero `validated` with any hard failure → `failed`
- aggregate manifest write failure → `failed` / `WRITE_FAILED` (child results remain in `outputs`; do not treat the set as validated)

Cross-process output locking surrounds resolve → ownership → cache → render → validate → commit. Contended jobs wait up to 60s, then return `OUTPUT_LOCKED` with `recommended_action: retry_same_request`.

## Safe hints (optional)

| Hint | Values | Purpose |
|------|--------|---------|
| `asset_class` | `automatic`, `weapon`, `armor`, `consumable`, `resource`, `generic` | Semantic inventory type when game metadata knows it |
| `orientation_hint` | `automatic`, `upright`, `horizontal`, `diagonal` | Framing orientation |
| `framing_bias` | `automatic`, `tighter`, `looser` | Occupancy bias |

Morphology (elongated, flat, tall, etc.) affects orientation only — not semantic type. Human sidecar corrections **override** hints.

## Purposes

| Purpose | Output contract |
|---------|-----------------|
| `inventory_icon` | 256×256, transparent |
| `shop_thumbnail` | 128×128, transparent |
| `equipment_preview` | 512×512, transparent (always `equipment_preview` preset) |
| `npc_portrait` | 256×256, gradient background |
| `creature_portrait` | 256×256, gradient background |
| `boss_portrait` | 512×512, gradient background |
| `neutral_thumbnail` | 256×256, transparent |

## asset_id rules

- Optional. When omitted, a collision-resistant default is derived from the **workspace-relative** source path (`basename__hash`), so moving the Enigma checkout does not rename generated files.
- When provided: non-empty, filename-safe lowercase, max 128 chars, no path separators or traversal.
- Two different sources must not silently share the same output identity.
- `force: true` bypasses cache only. It never overrides `ASSET_ID_COLLISION` or `OUTPUT_OWNERSHIP_UNKNOWN`.
- An existing PNG without a trustworthy adjacent `.owner.json` record is `OUTPUT_OWNERSHIP_UNKNOWN`, not unowned.

## Human sidecars

Durable `<source>.icon.json` corrections are a **human/maintainer** mechanism. They win over agent hints. Safe-mode callers must not invent sidecar fields, camera values, or lighting.

Sidecar JSON is **recursively strict**. Unknown keys are rejected at every nesting level, including `camera`, `lighting`, `composition`, and `environment`. Known fields are type-, range-, and enum-checked. A typo such as `"ocupancy"` or a value such as `"camera": {"fov": "banana"}` fails closed.

Canonical lighting keys (human sidecars only; not part of the safe Machine API):

- `lighting.rig`, `lighting.ambient_energy`
- `lighting.key` / `fill` / `rim`: `angle`, `intensity`, `color`, `shadow`

If a sidecar exists and cannot be parsed or fails validation, the render **stops** with `OVERRIDE_INVALID` and `recommended_action: fix_human_sidecar`. Invalid human corrections are never silently ignored, and they never overwrite an existing valid artifact.

## Output locations

Under `<workspace_root>/generated/` by purpose category, e.g. `generated/icons/inventory/sword__abc12345.png`. Callers cannot specify arbitrary paths in safe mode. Review records live at `<workspace_root>/generated/review_queue.json`.

## Cache semantics

`cache_hit: true` is returned only when:

1. A production manifest exists for the current deterministic `job_id`
2. Manifest identity matches current source hash, dependencies, asset_id, purpose, recipe revision, effective configuration hash, hints, and output SHA-256
3. Output still passes production quality validation

Changing source, sidecar, hints, preset content, or tool version invalidates the cache. A PNG without a matching manifest is never a cache hit. `force` regenerates the same logical asset; it does not steal another source's output path.

## Manifest semantics

`validated` is returned only when the PNG, matching production manifest, and output ownership record were committed. If the manifest or ownership write fails after replacing the PNG, the previous valid artifact is restored (or the unmanifested PNG is removed) and the API returns `WRITE_FAILED`.

`validate_output` checks visual production constraints **and** provenance when a production record exists. A mismatch of source identity, source hash, purpose, or output SHA-256 returns `MANIFEST_MISMATCH`. Opaque images without matching production metrics return `VALIDATION_METADATA_REQUIRED`.

`validated` means the requested purpose produced an artifact that satisfies Icon Forge's technical production contract. It does not prove that the mesh is semantically an NPC, weapon, or other subject class.

Cache hits return the same `manifest` field. Safe-mode `explain_result` should use `job_id`. A `manifest` path is accepted only if it is inside `<workspace>/generated/manifests/`.

## Response examples

**validated:**

```json
{
  "success": true,
  "status": "validated",
  "job_id": "...",
  "output": {"path": "generated/icons/inventory/sword__abc.png", "sha256": "...", "width": 256, "height": 256},
  "recipe": {"id": "weapon", "revision": 1},
  "manifest": "generated/manifests/....json",
  "cache_hit": false
}
```

**needs_review:**

```json
{
  "success": false,
  "status": "needs_review",
  "code": "FRAMING_UNRESOLVED",
  "recommended_action": "manual_composition_review",
  "manifest": "generated/manifests/....json"
}
```

**failed:**

```json
{
  "success": false,
  "status": "failed",
  "code": "SOURCE_NOT_FOUND",
  "recommended_action": "provide_supported_source"
}
```

## Expert mode (maintainers only)

```bash
./scripts/iconforge api --request expert.json --expert --json
```

Not for normal agent integration.

## Related docs

- [AGENTS.md](../AGENTS.md) — persona split and decision algorithm
- [AI_WORKFLOW.md](AI_WORKFLOW.md) — pointer to this document
- [OUTPUT_MANIFEST.md](OUTPUT_MANIFEST.md) — manifest field reference
