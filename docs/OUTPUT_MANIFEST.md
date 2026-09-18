# Output manifest

When enabled, batch rendering writes a JSON manifest at the requested path (default: `<output>/manifest.json`). Its shape is:

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

