# Machine API

> **Primary interface for AI agents.** Autonomous agents integrate through this API — not by scraping terminal output or guessing renderer parameters.

## Source path resolution

When `--workspace-root` or `ICONSTUDIO_WORKSPACE_ROOT` is set, relative `asset` paths resolve under that workspace first.

| `asset` value | Resolves to |
|---------------|-------------|
| `assets/items/sword.glb` | `<workspace_root>/assets/items/sword.glb` |
| `res://fixtures/sword.gltf` | Icon Studio repository resource |
| `/absolute/path/model.glb` | Explicit absolute path |

## Transport

```bash
./scripts/iconstudio api --request request.json --json
```

Optional workspace (recommended for Enigma):

```bash
export ICONSTUDIO_WORKSPACE_ROOT=/path/to/enigma
./scripts/iconstudio api --workspace-root "$ICONSTUDIO_WORKSPACE_ROOT" --request request.json --json
```

Official Python wrapper: [examples/enigma_client.py](../examples/enigma_client.py) (uses temporary request files, not stdin).

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

- all `validated` → `validated`
- at least one `validated` plus any non-validated → `partial_success`
- zero `validated`, all `needs_review` → `needs_review`
- zero `validated` with any hard failure → `failed`

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
- `force: true` bypasses cache only. It never overrides `ASSET_ID_COLLISION` ownership.

## Human sidecars

Durable `<source>.icon.json` corrections win over agent hints.

If a sidecar exists and cannot be parsed or fails strict field validation, the render **stops** with `OVERRIDE_INVALID`. Invalid human corrections are never silently ignored.

## Output locations

Under `<workspace_root>/generated/` by purpose category, e.g. `generated/icons/inventory/sword__abc12345.png`. Callers cannot specify arbitrary paths in safe mode. Review records live at `<workspace_root>/generated/review_queue.json`.

## Cache semantics

`cache_hit: true` is returned only when:

1. A production manifest exists for the current deterministic `job_id`
2. Manifest identity matches current source hash, dependencies, asset_id, purpose, recipe revision, effective configuration hash, hints, and output SHA-256
3. Output still passes production quality validation

Changing source, sidecar, hints, preset content, or tool version invalidates the cache. A PNG without a matching manifest is never a cache hit. `force` regenerates the same logical asset; it does not steal another source's output path.

## Manifest semantics

`validated` is returned only when the PNG and matching production manifest were both committed. If the manifest write fails after replacing the PNG, the previous valid artifact is restored (or the unmanifested PNG is removed) and the API returns `WRITE_FAILED`.

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
./scripts/iconstudio api --request expert.json --expert --json
```

Not for normal agent integration.

## Related docs

- [AGENTS.md](../AGENTS.md) — persona split and decision algorithm
- [AI_WORKFLOW.md](AI_WORKFLOW.md) — pointer to this document
- [OUTPUT_MANIFEST.md](OUTPUT_MANIFEST.md) — manifest field reference
