# Icon Forge agent guide

## Personas

### A. Machine consumer (Enigma agents, CI, external tools)

**Use only the semantic Machine API.** See [docs/MACHINE_API.md](docs/MACHINE_API.md).

- Call `capabilities` / `schema` for discovery, then `render_asset` or `render_asset_set`.
- **NEVER** use `--expert`, legacy `render` commands, preset IDs, or manual output paths.
- **NEVER** invent camera, lighting, occupancy, or framing values.
- **NEVER** retry `needs_review` by guessing renderer parameters.

Transport: `api --request FILE --json` (or the official [examples/enigma_client.py](examples/enigma_client.py) wrapper).

Workspace: set `ICONFORGE_WORKSPACE_ROOT` or pass `--workspace-root` so generated artifacts land in the caller project (not only this repository). Relative asset paths are workspace-exclusive; use `res://` only for intentional tool-repository resources.

### B. Repository maintainer (humans and authorized debug tooling)

You may use the GUI, expert CLI (`render --preset …`), preset JSON, and `render-batch`. Label those paths as maintainer/expert workflows in docs — not the normal agent path.

---

## Agent decision algorithm

After every `render_asset` or `render_asset_set` response:

| `status` | Action |
|----------|--------|
| `validated` | Consume `output.path` and `manifest`. Cache hits are valid only when `manifest` is present and matches current identity. |
| `partial_success` | Consume only child entries whose `status` is `validated`. Surface remaining children to a human/review workflow. |
| `needs_review` | **Stop.** Do not guess overrides. Do not switch to expert mode. Surface `recommended_action` to a human. |
| `failed` | Follow `recommended_action` only. Fix the request or source if applicable. Never invent renderer parameters. |

---

## What this tool does

Icon Forge converts GLB/glTF models and static images into consistent PNG game imagery. You specify **semantic intent** (`purpose`); Icon Forge owns inspection, recipe resolution, rendering, bounded correction, validation, and commit.

**Philosophy:** Agents specify intent. Icon Forge owns rendering.

## Expected machine workflow

1. Discover with `{"operation":"capabilities"}` or `{"operation":"schema"}`.
2. Render with `{"operation":"render_asset","asset":"…","purpose":"inventory_icon"}`.
3. Read `status`, `recipe`, `quality`, `manifest`, and `recommended_action` on failure.
4. For multiple outputs from one source, use `render_asset_set` (source inspected once).
5. Human corrections in `<source_basename>.icon.json` sidecars override agent hints and apply to future renders.

Machine workflows must use `--json`. Every response is one JSON object with stable error codes.

## What you should send

| Field | Example | Required |
|-------|---------|----------|
| `schema_version` | `1` (integer) | yes |
| `operation` | `render_asset` | yes |
| `asset` | `assets/items/sword.glb` | yes |
| `purpose` | `inventory_icon` | yes (for render) |

Optional safe hints: `asset_class`, `orientation_hint`, `framing_bias` — see [docs/MACHINE_API.md](docs/MACHINE_API.md).

## What you must NOT send (safe mode)

- `yaw`, `pitch`, `roll`, `fov`, `occupancy`, `padding`, `scale`
- `preset` IDs (resolved internally from `purpose` + optional `asset_class` hint)
- Arbitrary `output` paths (destination chosen by purpose registry under `generated/`)
- Unknown fields (rejected with `UNKNOWN_FIELD`)

## Maintainer-only topics

Preset JSON, expert CLI, GUI workflows, and batch manifests are documented under `docs/` for contributors. Agents should not need them.

## Validation and quality rules

`success: true` with `status: validated` means the output passed the **production contract**. A cache hit is returned only when the existing PNG is cryptographically tied to the current source, dependencies, effective configuration, sidecar, hints, recipe revision, and tool version via its production manifest.

## Safe editing rules (if you modify this repo)

- Never overwrite a source model or source image.
- Keep canonical preset fields in JSON and shared behavior in `core/` services.
- Do not bypass `ApiService`, `RenderService`, `PresetDefinition`, `AssetInspector`, or `QualityService`.
- Run `./scripts/quality-gate` after changes to rendering, presets, CLI, fixtures, API, or output validation.

## Canonical quality command

```bash
./scripts/quality-gate
```
