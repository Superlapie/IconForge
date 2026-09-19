# Preset schema

> **AI agents:** discover the machine API schema with `{"operation":"schema"}`, not preset JSON. Preset schema is for contributors and expert tooling.

Canonical preset schema version is `1`. The authoritative preset description for expert CLI is:

```bash
./scripts/iconforge schema --json
```

The machine API schema (operations, purposes, request fields) is separate and returned by:

```bash
./scripts/iconforge api --request <(printf '%s' '{"schema_version":1,"operation":"schema"}') --json
```

## preset_revision

Every preset file includes `preset_revision` (integer ≥ 1). Bump it when any field that affects rendered output changes (resolution, camera, lighting, environment, shadows, post-process, composition). Job identity and cache keys include `preset_revision` — bumping invalidates stale cached output for that recipe.

Do **not** bump for documentation-only edits (`display_name`, `description`, `tags`).

## Minimal valid preset

```json
{
  "schema_version": 1,
  "preset_revision": 1,
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
  "post_process": {"alpha_threshold": 0.01},
  "output": {"format": "png", "transparent": true}
}
```

Validate before committing:

```bash
./scripts/iconforge validate-preset presets/my_item.json --json
```

Increment `preset_revision` when rendering semantics change materially. Manifests record the revision that produced each output.
