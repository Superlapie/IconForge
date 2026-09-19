# AI workflow

> **Normal agent integration uses only [MACHINE_API.md](MACHINE_API.md).** This page is a short pointer — not a second contract.

## Machine consumer checklist

1. Read [AGENTS.md](../AGENTS.md) persona A and the decision algorithm.
2. Call `capabilities` then `schema` via `api --request FILE --json`.
3. Set `ICONSTUDIO_WORKSPACE_ROOT` (or `--workspace-root`) to your project root.
4. Call `render_asset` or `render_asset_set` with a `purpose`.
5. On `validated`, use `output.path` and `manifest`. On `needs_review`, stop and escalate.

## Official client

```python
from examples.enigma_client import IconStudioClient

client = IconStudioClient(workspace_root="/path/to/enigma")
result = client.render_asset("assets/sword.glb", "inventory_icon")
```

## Maintainer / expert paths

GUI, `render --preset`, `render-batch`, and `--expert` API mode are for humans and debug tooling. Do not teach normal agents to use them. See [QUICKSTART.md](QUICKSTART.md) for the human GUI path.
