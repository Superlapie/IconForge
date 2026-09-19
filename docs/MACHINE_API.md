# Machine API

Icon Studio exposes a **semantic safe-mode API** for AI agents and Enigma tooling. Agents specify **what** they want; Icon Studio owns rendering decisions.

## Normal workflow

Discover capabilities:

```bash
echo '{"schema_version":1,"operation":"capabilities"}' | ./scripts/iconstudio api --stdin --json
```

Render a single asset:

```bash
./scripts/iconstudio api --request examples/render_inventory.json --json
```

```json
{
  "schema_version": 1,
  "operation": "render_asset",
  "asset": "fixtures/sword.gltf",
  "purpose": "inventory_icon"
}
```

Render multiple outputs from one source (inspected once, rendered independently):

```json
{
  "schema_version": 1,
  "operation": "render_asset_set",
  "asset": "fixtures/sword.gltf",
  "outputs": ["inventory_icon", "shop_thumbnail", "equipment_preview"]
}
```

## Philosophy

**Good** (normal agent request):

```json
{
  "schema_version": 1,
  "operation": "render_asset",
  "asset": "assets/items/runic_sword.glb",
  "purpose": "inventory_icon"
}
```

**Bad** (expert/debug only — rejected in safe mode):

```json
{
  "yaw": 31,
  "pitch": -12,
  "fov": 38,
  "occupancy": 0.84
}
```

## Operations (safe mode)

| Operation | Description |
|-----------|-------------|
| `capabilities` | Supported operations, purposes, file types, tool version |
| `schema` | Executable field definitions, enums, error codes |
| `inspect_asset` | Deterministic source inspection |
| `render_asset` | Inspect → resolve recipe → render → validate → commit |
| `render_asset_set` | Multiple purposes from one source |
| `validate_output` | Validate existing PNG against purpose contract |
| `explain_result` | Deterministic trace from job ID or manifest |

## Purposes

| Purpose | Typical use |
|---------|-------------|
| `inventory_icon` | Inventory grid icon |
| `shop_thumbnail` | Shop listing |
| `equipment_preview` | Equipment slot preview |
| `npc_portrait` | NPC portrait frame |
| `creature_portrait` | Creature portrait |
| `boss_portrait` | Boss portrait |
| `neutral_thumbnail` | Generic thumbnail |

Icon Studio resolves the internal preset (e.g. `weapon` vs `inventory_item`) from inspection morphology. Callers do not choose presets in safe mode.

## Statuses

| Status | Meaning |
|--------|---------|
| `validated` | Output passed production quality contract |
| `partial_success` | Some outputs in a set succeeded; others need review or failed |
| `needs_review` | Bounded correction exhausted; human review recommended |
| `failed` | Hard failure (bad request, missing source, write error) |

## Response shape (success)

```json
{
  "schema_version": 1,
  "success": true,
  "status": "validated",
  "operation": "render_asset",
  "job_id": "...",
  "asset_id": "sword",
  "purpose": "inventory_icon",
  "output": {
    "path": "generated/icons/inventory/sword.png",
    "sha256": "...",
    "width": 256,
    "height": 256
  },
  "recipe": {"id": "weapon", "revision": 1},
  "quality": {"status": "pass", "occupancy": 0.819, "clipped": false},
  "manifest": "generated/manifests/....json",
  "cache_hit": false
}
```

## Error recovery

Every failure includes `code` and `recommended_action` (e.g. `provide_supported_source`, `manual_composition_review`). Agents should not infer recovery from prose.

Unknown fields, invalid enums, and path traversal are **rejected** — never silently ignored.

## Expert mode

Low-level control (`preset`, `yaw`, arbitrary `output` paths) is available via `render_expert` with `--expert`:

```bash
./scripts/iconstudio api --request expert_render.json --expert --json
```

Expert mode is for GUI parity, debugging, and authorized tooling — not normal Enigma agent calls.

## Enigma client

See `examples/enigma_client.py` for a minimal Python wrapper. Transport can later change to a persistent worker without changing the request contract.

## Filesystem safety

Safe mode writes only under `generated/` using purpose-defined categories. Callers cannot specify arbitrary output paths.

## Sidecars

Human corrections in `<source>.icon.json` are loaded automatically. Future safe-mode renders inherit durable corrections without agent knowledge.

## Idempotency

Repeated identical requests reuse validated cached output (`cache_hit: true`) and the same deterministic destination path.
