# Icon Forge local MCP

Icon Forge ships a **local stdio MCP adapter** at `mcp/`. It is transport only: all rendering, validation, provenance, and commits remain in `ApiService`.

## Architecture

```text
Cursor / Claude / MCP host
        ↓ stdio JSON-RPC
TypeScript MCP server (iconforge-mcp)
        ↓ persistent child JSONL
iconforge service
        ↓
IconForgeService → ApiService
```

No hosting, HTTP, or remote transport is required.

## Tools

| MCP tool | Machine API operation |
| -------- | --------------------- |
| `iconforge_capabilities` | `capabilities` |
| `iconforge_schema` | `schema` |
| `iconforge_inspect_asset` | `inspect_asset` |
| `iconforge_render_asset` | `render_asset` |
| `iconforge_render_asset_set` | `render_asset_set` |
| `iconforge_validate_output` | `validate_output` |
| `iconforge_explain_result` | `explain_result` |

Expert renderer controls are **not** exposed. Safe-mode hints only.

## Installation (development)

```bash
cd mcp
npm ci
npm run build
```

Requires Node.js 20+, a local Icon Forge install (Godot + `scripts/iconforge`), and `ICONFORGE_ROOT` pointing at the Icon Forge repository or install tree.

## Cursor configuration

Copy and edit [examples/cursor-mcp.json](../examples/cursor-mcp.json) into your **game project** as `.cursor/mcp.json` (not into the Icon Forge repo). Set:

- `ICONFORGE_ROOT` — Icon Forge install path
- `ICONFORGE_WORKSPACE_ROOT` / `${workspaceFolder}` — Enigma or game project root

Verify in Cursor: **Customize → MCP**, or `agent mcp list-tools iconforge`.

## Environment variables

| Variable | Purpose |
| -------- | ------- |
| `ICONFORGE_ROOT` | Icon Forge install directory |
| `ICONFORGE_WORKSPACE_ROOT` | Caller project workspace |
| `ICONFORGE_COMMAND` | Explicit `iconforge` executable |
| `ICONFORGE_MCP_TIMEOUT_MS` | Per-request timeout (default 300000) |
| `ICONFORGE_MCP_DEBUG` | `1` for stderr diagnostics |

## Offline behavior

MCP works offline once Icon Forge and Godot are installed locally. The adapter does not download runtimes or clone repositories at tool-call time.

## Minimum Icon Forge version

MCP requires Icon Forge **v0.2.0+** (Machine API schema version `1` with persistent `service` transport).

## npm publication

The `iconforge-mcp` package is publish-ready but **not published** yet. Future installs may use `npx iconforge-mcp` once released.

## Lifecycle

- Normal shutdown sends the service `shutdown` request and waits briefly before any forced cleanup.
- Timeout, cancellation, or protocol failure forcibly terminates the entire local Icon Forge service process tree.
- The next MCP request waits for cleanup to finish, then launches a fresh service child with a new handshake.
- In-flight requests are never automatically replayed after forced termination.

## Troubleshooting

- **SERVICE_STDIN_UNAVAILABLE** — upgrade to a build with cross-platform service stdin; ensure MCP spawns `iconforge service` with piped stdin.
- **ICONFORGE_NOT_FOUND** — set `ICONFORGE_ROOT` or `ICONFORGE_COMMAND`.
- **Protocol errors** — service stdout must be JSON-lines only; check `scripts/iconforge service` wrapper filters Godot banners.

## MCP Inspector

```bash
cd mcp && npm run build
npx @modelcontextprotocol/inspector node dist/index.js --iconforge-root /path/to/IconForge --workspace-root /path/to/your/game
```
