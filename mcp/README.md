# MCP adapter plan

Icon Forge's canonical boundary is `ApiService`. MCP tools must be thin wrappers over the same operations.

## Planned tool mapping

| MCP tool | Machine API operation |
| -------- | --------------------- |
| `iconforge.capabilities` | `capabilities` |
| `iconforge.schema` | `schema` |
| `iconforge.inspect_asset` | `inspect_asset` |
| `iconforge.render_asset` | `render_asset` |
| `iconforge.render_asset_set` | `render_asset_set` |
| `iconforge.validate_output` | `validate_output` |
| `iconforge.explain_result` | `explain_result` |

Expert rendering controls are intentionally **not** exposed as MCP tools.

## Transport

Phase A (implemented): persistent local `iconforge service` JSON-lines process.

Phase B (deferred): MCP server process that forwards tool calls to the service or `ApiService` in-process.

No MCP server is shipped yet. Do not claim MCP support until an integration test exercises a real MCP client against a real server implementation.

## Reference client pattern

Use `examples/enigma_client.py` or pipe JSON lines to `iconforge service` from your adapter.
