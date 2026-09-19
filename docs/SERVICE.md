# Persistent service transport

Icon Forge keeps **all business logic in `ApiService`**. The `service` command is a thin JSON-lines transport.

## Invocation

```bash
printf '%s\n' '{"schema_version":1,"operation":"capabilities"}' | ./scripts/iconforge service
```

One JSON object per line on stdin. One JSON response per line on stdout. Diagnostics belong on stderr (Godot logs), not mixed into stdout.

## Shutdown

```json
{"schema_version":1,"operation":"shutdown"}
```

## Concurrency

Requests inside one Godot process are serialized intentionally. Multiple agents may share one service process or run separate processes; production output locking still protects committed artifacts across processes.

## MCP

A future MCP adapter must map tools directly to semantic Machine API operations without duplicating validation or rendering logic. See `mcp/README.md` for the planned mapping.
