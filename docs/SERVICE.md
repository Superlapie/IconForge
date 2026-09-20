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

Responses use the same Machine API envelope as `api` (`schema_version`, `success`, `status`, `operation`, and on failure `code`, `message`, `recommended_action`). Transport startup failures (for example when stdin is not piped) return `SERVICE_STDIN_UNAVAILABLE`.

## Concurrency

Requests inside one Godot process are serialized intentionally. Multiple agents may share one service process or run separate processes; production output locking still protects committed artifacts across processes.

## MCP

The local MCP adapter (`mcp/`) forwards tool calls to this transport. See [MCP.md](MCP.md).
