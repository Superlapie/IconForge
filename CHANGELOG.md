# Changelog

All notable changes to Icon Forge are documented here.

The format is inspired by [Keep a Changelog](https://keepachangelog.com/).

## Unreleased

### Added
- Local stdio MCP adapter (`mcp/`, package `iconforge-mcp` 0.1.0) with safe semantic tools over persistent `iconforge service`
- Cross-platform service stdin via `OS.read_buffer_from_stdin` and `OS.get_stdin_type()` (Node pipe children on Linux)
- Service stdout JSON purity filtering in `scripts/iconforge` / `scripts/iconforge.ps1`
- MCP bridge unit tests, full MCP client E2E, `scripts/mcp-contract-e2e`, `scripts/mcp-e2e`
- Cursor configuration example at `examples/cursor-mcp.json` and `docs/MCP.md`

## 0.2.0 — 2026-09-19

Hardened Machine API beta and product maturity release.

### Added
- Semantic Machine API (`render_asset`, `render_asset_set`, `inspect_asset`, `validate_output`, `capabilities`, `schema`, `explain_result`)
- External `.gltf` dependency provenance with percent-decoded filesystem URIs
- Production manifests, owner records, and output provenance
- Per-job review records under `generated/reviews/`
- Cross-process output locking with Linux PID + start-time validation
- Transactional validated commits with rollback recovery paths
- Source and dependency mutation detection before commit
- Real-model, GUI, GUI interaction, Enigma client, and lock E2Es
- Structured machine errors with `recommended_action`
- Persistent JSON-lines `service` transport over stdin/stdout
- Cross-platform `contract-gate` CI workflow
- Pinned Godot runtime metadata and SHA-256 verification for Linux, Windows, and macOS CI
- Bootstrap script and Windows PowerShell wrapper
- Per-record advisory indexes for output and review summaries
- Per-key expert cache record files with lazy legacy migration

### Changed
- Product rename: Icon Studio → Icon Forge
- Agent-safe request model; renderer controls rejected in safe mode
- Cache/job identity now includes tool version, dependencies, and effective config hash
- Review architecture: authoritative per-job files + advisory queue index
- Advisory cache/index writes no longer require whole-file read/modify/write for correctness

### Fixed
- Rollback edge cases, including deletion-failure surfacing as `ROLLBACK_FAILED`
- Stale lock recovery and orphan lease temp recovery
- Linux PID reuse false authority
- glTF percent-encoded URI dependency tracking
- Source mutation races during render
- Manifest/ownership consistency and API boundary field loss

## 0.1.0

Initial open-source preview.
