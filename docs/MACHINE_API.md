# Machine API

> **Primary interface for AI agents.** Icon Studio is built so autonomous agents integrate through this API — not by scraping terminal output or guessing renderer parameters.

Icon Studio exposes a **semantic safe-mode API**. Agents specify **what** they want; Icon Studio owns rendering decisions.

## Who this is for

- Enigma content pipeline workers
- Cursor / Copilot / custom coding agents
- CI/CD and batch automation
- Any tool that needs deterministic, validated game imagery without renderer expertise

Humans and debuggers may use the GUI or expert CLI. **Normal agent integration starts here.**

## Normal workflow

Discover capabilities:

```bash
./scripts/iconstudio api --request <(printf '%s' '{"schema_version":1,"operation":"capabilities"}') --json
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

The good path is dramatically easier than the bad path. Unknown fields are rejected, not silently ignored.

## Safety guarantees

An imperfect agent should only produce:

1. **validated correct output**
2. **deterministically auto-corrected + validated output**
3. **`needs_review` / `failed`** with `recommended_action`

There is no normal path to `success: true` with invalid output.

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

## Expert mode

Low-level control (`preset`, `yaw`, arbitrary `output` paths) is available via `render_expert` with `--expert`:

```bash
./scripts/iconstudio api --request expert_render.json --expert --json
```

Expert mode is for GUI parity, debugging, and authorized tooling — **not normal agent calls**.

## Enigma client

See [examples/enigma_client.py](../examples/enigma_client.py) for a minimal Python wrapper. Transport can later change to a persistent worker without changing the request contract.

## Filesystem safety

Safe mode writes only under `generated/` using purpose-defined categories. Callers cannot specify arbitrary output paths.

## Sidecars

Human corrections in `<source>.icon.json` are loaded automatically. Future safe-mode renders inherit durable corrections without agent knowledge.

## Idempotency

Repeated identical requests reuse validated cached output (`cache_hit: true`) and the same deterministic destination path.

## Related docs

- [AGENTS.md](../AGENTS.md) — canonical agent integration guide
- [AI_WORKFLOW.md](AI_WORKFLOW.md) — step-by-step workflow
- [ARCHITECTURE.md](ARCHITECTURE.md) — how the API sits above render services
