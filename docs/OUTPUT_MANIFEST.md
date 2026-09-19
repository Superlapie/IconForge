# Output manifest

Manifests are the **production audit record** for agents and humans. Do not reverse-engineer PNG state — read the manifest.

## Machine API manifests

Every successful `render_asset` or `render_asset_set` entry writes a manifest to `generated/manifests/<job_id>.json` containing:

- `job_id`, `operation`, `purpose`, `source`, `source_hash`
- `recipe` (`id` + `revision`)
- `inspection_summary`, `resolution_reasons`
- `correction` history, `quality` metrics
- `output` path and SHA-256
- `trace` (render state machine path)

Use `explain_result` with a `job_id` to retrieve deterministic traceability.

## Legacy batch manifests

When enabled, expert `render-batch` writes a JSON manifest at the requested path (default: `<output>/manifest.json`):

```json
{
  "tool_version": "0.1.0",
  "preset": "inventory_item",
  "input": "assets/items",
  "output": "generated/icons",
  "generated_at": "2026-09-18T00:00:00Z",
  "summary": {"total": 2, "success": 2, "failed": 0},
  "renders": [
    {
      "source": "assets/items/iron_sword.glb",
      "output": "generated/icons/iron_sword.png",
      "status": "success",
      "cache_hit": false,
      "warnings": [],
      "errors": [],
      "metrics": {"occupancy": 0.82}
    }
  ]
}
```

JSON configuration and manifests are written through atomic temp-file replacement. The source is never an output target.
