# Security Policy

Icon Forge is a local/offline asset rendering tool. It processes user-supplied models and images and writes PNG outputs into a workspace. It is **not** a hostile-code sandbox.

## Supported Versions

| Version | Supported |
| ------- | --------- |
| 0.2.x   | Yes       |
| 0.1.x   | Best effort, no formal backport guarantee |
| < 0.1   | No        |

## Reporting a Vulnerability

Please report security issues privately using [GitHub Security Advisories](https://github.com/Superlapie/IconForge/security/advisories/new) for this repository.

Do not open public issues for exploitable vulnerabilities.

If GitHub private reporting is unavailable, open a minimal public issue asking for a private contact channel and wait for maintainer response before sharing details.

## Scope

In-scope examples:

- Workspace path escapes or writes outside the configured workspace in safe mode
- Arbitrary filesystem writes from Machine API safe mode
- Command execution from normal agent requests
- Unsafe external dependency resolution leading to provenance bypass
- Symlink/path traversal that bypasses workspace policy
- Output lock bypass that can corrupt committed production artifacts
- Crafted requests that bypass safe-mode renderer-control restrictions

Out of scope or usually treated as bugs rather than security issues:

- Malformed models that fail to render
- Low-quality or `needs_review` imagery
- Expert/legacy CLI misuse by trusted operators
- Performance issues without a security impact

## Trust Model

- Icon Forge is intended to run locally with trusted callers.
- Godot parses and renders supplied assets; treat untrusted assets as untrusted input to a native parser/renderer.
- Safe mode restricts output destinations and rejects renderer-control fields.
- Expert mode and maintainer tooling expose broader capabilities and should only be used by trusted humans or authorized debug tooling.
- The local MCP adapter (`mcp/`) is stdio-only, runs with the user's OS permissions, and exposes safe-mode semantic tools only. It must not reintroduce renderer controls or arbitrary output paths.
- MCP is not a sandbox: Godot still parses supplied assets locally.

## Dependency Surface

- Godot Engine runtime (pinned in `build/godot.env` for Linux CI/bootstrap)
- Python 3 for examples, E2E helpers, and CI scripts only
- Node.js 20+ for the optional local MCP adapter (`mcp/`) only

No network access is required for normal offline rendering once the runtime is installed.
