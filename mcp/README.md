# iconforge-mcp

Local stdio MCP adapter for [Icon Forge](../README.md). See [docs/MCP.md](../docs/MCP.md) for installation, Cursor setup, and architecture.

## Quick start

```bash
npm ci
npm run build
node dist/index.js --iconforge-root .. --workspace-root /path/to/your/game
```

## Tests

```bash
npm test          # bridge unit tests (no Godot)
npm run test:e2e  # full MCP client + Icon Forge render E2E
```

From repository root:

```bash
./scripts/mcp-contract-e2e
./scripts/mcp-e2e
```
