# Preset schema

Canonical schema version is `1`. The authoritative machine description is returned by:

```bash
./scripts/iconstudio schema --json
```

Minimal valid preset:

```json
{
  "schema_version": 1,
  "id": "my_item",
  "display_name": "My Item",
  "description": "A reusable item composition.",
  "tags": ["item"],
  "resolution": {"width": 256, "height": 256},
  "supersampling": 2,
  "projection": "orthographic",
  "camera": {
    "orientation_strategy": "preserve",
    "yaw": 18,
    "pitch": -8,
    "roll": 0,
    "occupancy": 0.82,
    "padding": 0.08,
    "auto_frame": true
  },
  "lighting": {"rig": "neutral_studio"},
  "environment": {"background": "transparent"},
  "shadows": {"mode": "contact"},
  "post_process": {"alpha_threshold": 0.01},
  "composition": {"center_mode": "aabb", "scale": 1},
  "output": {"format": "png", "transparent": true, "name_pattern": "{source_name}.png"}
}
```

Missing optional nested fields are filled from `PresetDefinition.default_data`. Invalid ranges are rejected: resolution 16–8192, supersampling 1–8, occupancy 0.05–0.99, padding 0–0.45, FOV 5–170, and zoom bounds must be ordered. Legacy flat camera fields are migrated into the `camera` object and normalized to schema 1.

