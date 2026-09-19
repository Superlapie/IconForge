# AI workflow

> **Icon Studio is built for tool-using agents.** This document describes the normal integration path. If you are an AI agent, start with [AGENTS.md](../AGENTS.md) and [MACHINE_API.md](MACHINE_API.md).

Icon Studio is designed to be driven by structured JSON requests — not terminal scraping, not guessing preset field names, and not manual camera tuning.

## Recommended: semantic machine API

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

Agents specify **purpose**, not camera/lighting/FOV. Icon Studio inspects, resolves the recipe, renders, validates, and commits.

### Discover before you render

```bash
./scripts/iconstudio api --request <(printf '%s' '{"schema_version":1,"operation":"capabilities"}') --json
./scripts/iconstudio api --request <(printf '%s' '{"schema_version":1,"operation":"schema"}') --json
```

The executable schema is the source of truth. Do not guess field names.

### Multiple outputs from one asset

```json
{
  "schema_version": 1,
  "operation": "render_asset_set",
  "asset": "fixtures/sword.gltf",
  "outputs": ["inventory_icon", "shop_thumbnail", "equipment_preview"]
}
```

### Handle outcomes

| Result | What to do |
|--------|------------|
| `success: true`, `status: "validated"` | Use `output.path`, record `manifest` |
| `status: "needs_review"` | Read `recommended_action`; do not treat as success |
| `status: "partial_success"` | Check each entry in `outputs` |
| `success: false` | Read `code` and `recommended_action`; fix request or escalate |

### Idempotency

Call the same valid request again — Icon Studio returns `cache_hit: true` with the same artifact. Do not invent new output paths.

## Expert / legacy CLI (debugging and humans only)

These commands expose renderer internals. **Do not teach normal agents to use them.**

```bash
./scripts/iconstudio inspect assets/iron_sword.glb --json
./scripts/iconstudio render assets/iron_sword.glb --preset weapon --output out/iron_sword.png --force --json
./scripts/iconstudio validate-output out/iron_sword.png --preset weapon --json
```

If framing needs human correction, save a sidecar (`iron_sword.icon.json`). The next safe-mode `render_asset` call inherits it automatically.

## Batch (expert)

For many sources with one preset:

```bash
./scripts/iconstudio render-batch assets/items \
  --preset inventory_item \
  --output generated/icons \
  --manifest generated/icons/manifest.json \
  --json
```

For many purposes on one source, prefer `render_asset_set` instead.

## Determinism and cache

The cache is keyed by source hash, resolved recipe, overrides, and tool version. Use `force: true` in API requests when intentionally replacing output. Do not manually edit cache entries.
