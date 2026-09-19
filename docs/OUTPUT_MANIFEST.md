# Output manifest

Manifests are the **production audit record** for agents and humans. Do not reverse-engineer PNG state — read the manifest.

## Machine API manifests

Every successful `render_asset` writes a manifest to `<workspace>/generated/manifests/<job_id>.json` containing:

- `job_id`, `operation`, `purpose`, `status`
- `source`, `source_hash`, `source_identity`, `dependency_hashes`
- `asset_id`, `hints`, `effective_override`, `effective_config_hash`
- `recipe` (`id` + `revision`)
- `inspection_summary`, `resolution_reasons`
- `correction` history, `quality` metrics (including silhouette metrics for opaque portraits)
- `output` path, dimensions, and SHA-256
- `tool_version`, `cache_hit`, `trace`

`render_asset_set` also writes an aggregate manifest with `child_job_ids`, `children`, and `summary`.

Cache-hit responses include the same `manifest` path — agents must not consume artifacts without manifest traceability.

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
